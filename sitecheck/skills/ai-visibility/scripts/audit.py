#!/usr/bin/env python3
"""Deterministic AI-crawler-visibility audit for one site.

Fetches robots.txt, llms.txt and the sitemap (following a sitemap index and
gzip sitemaps if present), tabulates page counts and lastmod cadence, tests
whether a sample of content URLs actually returns 200 to a set of named AI
crawler user-agents, cross-checks any growth claim against the Wayback
Machine's independently-observed first-seen dates, and (optionally) counts
URL-slug hits against a keyword list.

Stdlib only — no third-party dependencies, so this runs anywhere Python 3.9+
runs without a venv.

    python3 audit.py example.com
    python3 audit.py example.com --keywords foo,bar,baz --json out.json

This script does the *extraction*, not the interpretation. It will tell you
"robots.txt names these agents" and "lastmod says X pages in August, Wayback
first saw Y pages by June" — it will not tell you what that means (bulk
migration vs real growth vs archive lag). That's the judgment call the
SKILL.md asks for after this runs. See its "Interpreting the output" step.
"""
from __future__ import annotations

import argparse
import gzip
import json
import re
import sys
import urllib.error
import urllib.request
from collections import Counter
from urllib.parse import urljoin, urlparse
from xml.etree import ElementTree

BROWSER_UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
)

# Known AI-crawler / AI-assistant user-agent tokens, as of 2026-08. Sites
# increasingly name these individually in robots.txt rather than relying on
# a wildcard rule — which agent is (or isn't) named, and under what exact
# string, is itself a finding (a misspelled or outdated token is a no-op
# even when the site's evident intent is "allow this agent").
#
# Source-check before trusting this list for long: vendors add tokens
# (Anthropic and OpenAI both have, historically, roughly once or twice a
# year). Cross-reference against the vendor's current published list before
# treating an absence as meaningful.
KNOWN_AI_AGENTS = {
    "training/indexing": ["GPTBot", "ClaudeBot", "Google-Extended", "CCBot",
                            "Bytespider", "Applebot-Extended", "Amazonbot",
                            "cohere-ai", "Meta-ExternalAgent", "Diffbot",
                            "anthropic-ai"],
    "live retrieval (fetches on a user's behalf)": ["ChatGPT-User", "Claude-User",
                            "Claude-SearchBot", "PerplexityBot", "Perplexity-User",
                            "OAI-SearchBot"],
}
ALL_KNOWN_AGENTS = {a for group in KNOWN_AI_AGENTS.values() for a in group}

# UAs used for the live crawler-access test. Kept short and representative
# rather than exhaustive — extend with --uas if a specific agent matters.
DEFAULT_TEST_UAS = {
    "ChatGPT-User": "Mozilla/5.0 AppleWebKit/537.36 (KHTML, like Gecko); "
                     "compatible; ChatGPT-User/1.0; +https://openai.com/bot",
    "Claude-User": "Claude-User/1.0",
    "PerplexityBot": "Mozilla/5.0 (compatible; PerplexityBot/1.0; "
                      "+https://perplexity.ai/perplexitybot)",
    "GPTBot": "GPTBot/1.2",
    "ClaudeBot": "Mozilla/5.0 (compatible; ClaudeBot/1.0; "
                 "+claudebot@anthropic.com)",
    "CCBot": "CCBot/2.0 (https://commoncrawl.org/faq/)",
    "Googlebot": "Googlebot/2.1 (+http://www.google.com/bot.html)",
    "Browser": BROWSER_UA,
}


def fetch(url: str, ua: str = BROWSER_UA, timeout: int = 15):
    """Return (status_code, headers, body_bytes). status_code is None on a
    connection-level failure (timeout, DNS, refused) rather than an HTTP
    error status, which is returned normally."""
    req = urllib.request.Request(url, headers={"User-Agent": ua})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read()
            return resp.status, dict(resp.headers), body
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers or {}), e.read()
    except Exception as e:  # noqa: BLE001 - deliberately broad, this is a probe
        return None, {}, str(e).encode()


def status_only(url: str, ua: str, timeout: int = 15):
    """HEAD-first status check; falls back to GET for servers that mishandle
    HEAD (common). Returns int status or None."""
    req = urllib.request.Request(url, headers={"User-Agent": ua}, method="HEAD")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        pass
    status, _, _ = fetch(url, ua, timeout)
    return status


def maybe_decompress(body: bytes, headers: dict, url: str) -> bytes:
    if body[:2] == b"\x1f\x8b" or url.endswith(".gz") or \
            "gzip" in headers.get("Content-Encoding", "").lower():
        try:
            return gzip.decompress(body)
        except OSError:
            return body
    return body


def parse_robots(text: str):
    """Return (agent -> list[(directive, path)], sitemap_urls)."""
    agents: dict[str, list[tuple[str, str]]] = {}
    current: list[str] = []
    sitemaps: list[str] = []
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or ":" not in line:
            continue
        field, _, value = line.partition(":")
        field, value = field.strip().lower(), value.strip()
        if field == "user-agent":
            if current and current[-1] in agents and agents[current[-1]]:
                current = []  # new block starts
            current = current or []
            current.append(value)
            agents.setdefault(value, [])
        elif field in ("allow", "disallow", "crawl-delay") and current:
            for agent in current:
                agents.setdefault(agent, []).append((field, value))
        elif field == "sitemap":
            sitemaps.append(value)
        else:
            current = []  # any other directive ends the agent block chain
    return agents, sitemaps


def named_ai_agents(agents: dict) -> dict:
    """Which known AI-agent tokens actually appear as their own block."""
    found = {a: agents[a] for a in agents if a in ALL_KNOWN_AGENTS}
    return found


NS = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}


def parse_sitemap_xml(body: bytes):
    """Return ('urlset', [(loc, lastmod|None), ...]) or
    ('sitemapindex', [loc, ...])."""
    try:
        root = ElementTree.fromstring(body)
    except ElementTree.ParseError:
        return None, []
    tag = root.tag.rsplit("}", 1)[-1]
    if tag == "sitemapindex":
        locs = [el.text.strip() for el in root.findall(".//sm:sitemap/sm:loc", NS)
                 if el.text]
        if not locs:  # namespace-less fallback
            locs = [el.text.strip() for el in root.findall(".//loc") if el.text]
        return "sitemapindex", locs
    if tag == "urlset":
        rows = []
        for url_el in root.findall("sm:url", NS) or root.findall("url"):
            loc_el = url_el.find("sm:loc", NS)
            if loc_el is None:
                loc_el = url_el.find("loc")
            lastmod_el = url_el.find("sm:lastmod", NS)
            if lastmod_el is None:
                lastmod_el = url_el.find("lastmod")
            if loc_el is not None and loc_el.text:
                rows.append((loc_el.text.strip(),
                              lastmod_el.text.strip() if lastmod_el is not None and lastmod_el.text else None))
        return "urlset", rows
    return None, []


def discover_sitemap_roots(base: str, robots_sitemaps: list[str]) -> list[str]:
    if robots_sitemaps:
        return robots_sitemaps
    return [urljoin(base, "/sitemap.xml"), urljoin(base, "/sitemap_index.xml")]


def collect_sitemap_urls(base: str, robots_sitemaps: list[str], ua: str,
                          max_children: int = 60, max_depth: int = 2):
    """Walk sitemap index files (bounded) and return the flat list of
    (loc, lastmod) rows plus the list of sitemap files actually read."""
    roots = discover_sitemap_roots(base, robots_sitemaps)
    seen_files: list[str] = []
    rows: list[tuple[str, str | None]] = []
    queue = [(u, 0) for u in roots]
    visited = set()
    while queue:
        url, depth = queue.pop(0)
        if url in visited or depth > max_depth:
            continue
        visited.add(url)
        status, headers, body = fetch(url, ua)
        if status != 200 or not body:
            continue
        body = maybe_decompress(body, headers, url)
        kind, data = parse_sitemap_xml(body)
        if kind == "sitemapindex":
            seen_files.append(url)
            for child in data[:max_children]:
                queue.append((child, depth + 1))
        elif kind == "urlset":
            seen_files.append(url)
            rows.extend(data)
    return rows, seen_files


def month_histogram(dates: list[str]) -> Counter:
    return Counter(d[:7] for d in dates if d and len(d) >= 7)


def path_segment_histogram(urls: list[str], top_n: int = 15):
    def seg(u):
        parts = [p for p in urlparse(u).path.split("/") if p]
        return parts[0] if parts else "(root)"
    return Counter(seg(u) for u in urls).most_common(top_n)


def wayback_first_seen(domain: str, path_prefix: str | None, limit: int = 200000):
    """Query the Wayback Machine CDX API for first-seen timestamp per unique
    URL under domain[/path_prefix]. This is an independent third-party
    crawl record — not something the site being audited can shape — and is
    the check that catches a lastmod-based growth claim that's actually a
    bulk timestamp bump from a migration or template change rather than
    real new content."""
    url_arg = f"{domain}/{path_prefix.lstrip('/')}" if path_prefix else domain
    api = ("http://web.archive.org/cdx/search/cdx?"
           f"url={url_arg}&matchType=prefix&collapse=urlkey&output=json"
           f"&fl=original,timestamp&limit={limit}")
    status, _, body = fetch(api, BROWSER_UA, timeout=40)
    if status != 200 or not body:
        return None
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        return None
    rows = data[1:] if data else []
    hist = Counter(r[1][:6] for r in rows)  # YYYYMM
    return {"total_unique_urls": len(rows), "first_seen_by_month": dict(sorted(hist.items()))}


def crawler_access_matrix(urls: list[str], uas: dict[str, str]):
    return {url: {name: status_only(url, ua) for name, ua in uas.items()}
            for url in urls}


def keyword_counts(urls: list[str], keywords: list[str]):
    lowered = [u.lower() for u in urls]
    return {kw: sum(1 for u in lowered if kw.lower() in u) for kw in keywords}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("domain", help="bare domain, e.g. example.com or www.example.com")
    ap.add_argument("--keywords", default="", help="comma-separated URL-slug keywords to count, e.g. product names or topics")
    ap.add_argument("--sample-paths", default="", help="comma-separated content paths to run the crawler-access test against, e.g. /,/pricing")
    ap.add_argument("--cdx-path-prefix", default="", help="path prefix to scope the Wayback check to, e.g. guide (default: whole domain)")
    ap.add_argument("--skip-wayback", action="store_true")
    ap.add_argument("--skip-crawler-test", action="store_true")
    ap.add_argument("--json", default="", help="also write the full result as JSON to this path")
    args = ap.parse_args()

    domain = args.domain.strip().rstrip("/")
    if domain.startswith("http"):
        domain = urlparse(domain).netloc
    base = f"https://{domain}/"

    result: dict = {"domain": domain}

    # robots.txt
    status, _, body = fetch(urljoin(base, "/robots.txt"))
    robots_text = body.decode("utf-8", "replace") if status == 200 else ""
    agents, robots_sitemaps = parse_robots(robots_text) if robots_text else ({}, [])
    result["robots_txt"] = {
        "status": status,
        "raw": robots_text,
        "named_ai_agents": named_ai_agents(agents),
        "sitemap_directives": robots_sitemaps,
    }

    # llms.txt
    status, _, body = fetch(urljoin(base, "/llms.txt"))
    result["llms_txt"] = {
        "status": status,
        "present": status == 200,
        "bytes": len(body) if status == 200 else 0,
        "raw": body.decode("utf-8", "replace") if status == 200 else "",
    }

    # sitemap
    rows, files_read = collect_sitemap_urls(base, robots_sitemaps, BROWSER_UA)
    urls = [u for u, _ in rows]
    lastmods = [m for _, m in rows if m]
    result["sitemap"] = {
        "files_read": files_read,
        "total_urls": len(urls),
        "top_path_segments": path_segment_histogram(urls),
        "lastmod_coverage": f"{len(lastmods)}/{len(urls)}",
        "lastmod_by_month": dict(sorted(month_histogram(lastmods).items())) if lastmods else None,
    }

    # keyword breakdown
    if args.keywords:
        kws = [k.strip() for k in args.keywords.split(",") if k.strip()]
        result["keyword_counts"] = keyword_counts(urls, kws)

    # crawler access matrix
    if not args.skip_crawler_test:
        sample_paths = [p.strip() for p in args.sample_paths.split(",") if p.strip()] or ["/"]
        sample_urls = [urljoin(base, p) for p in sample_paths]
        result["crawler_access_matrix"] = crawler_access_matrix(sample_urls, DEFAULT_TEST_UAS)

    # Wayback cross-check
    if not args.skip_wayback:
        result["wayback_first_seen"] = wayback_first_seen(
            domain, args.cdx_path_prefix or None)

    print(json.dumps(result, indent=2, default=str))
    if args.json:
        with open(args.json, "w") as f:
            json.dump(result, f, indent=2, default=str)


if __name__ == "__main__":
    main()
