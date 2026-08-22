---
name: ai-visibility
description: Audits how visible a website is to AI crawlers and assistants — robots.txt (which agents are named, not just wildcarded), llms.txt, sitemap size and growth cadence, whether crawler access actually matches the stated policy, and a Wayback Machine cross-check that catches a self-reported growth number that's actually a migration bump. Use when asked to check a site's AI/LLM visibility, SEO-for-AI setup, whether a domain is "doing programmatic SEO" or has exploded in page count, or to compare one site's crawler-friendliness against another's.
model: sonnet
---

# /sitecheck:ai-visibility

Most of this skill is a deterministic script, not a prompt. `scripts/audit.py` (stdlib-only
Python, no dependencies) does every fetch, parse, and count. Your job is to run it, then do
the two things it can't: classify what the site actually *is*, and reconcile disagreements
in what it reports.

## Step 1 — Run the script

```
python3 scripts/audit.py <domain> \
  --keywords <comma-separated topic/product terms relevant to this site> \
  --sample-paths <comma-separated content paths to test crawler access against> \
  --json <scratch-path>/audit-<domain>.json
```

Pick `--keywords` from what the site is actually about — product names, service lines,
topics — not a fixed list. If you don't know yet, run once without `--keywords`, look at
`sitemap.top_path_segments` in the output to see what the site's content is organised
around, then re-run with a keyword list that matches.

`--sample-paths` defaults to `/` only. Add one or two real content URLs (not the homepage)
once you've seen the sitemap — the crawler-access test is more informative on a page that
matters (a product page, a guide) than on the homepage, which is almost always open.

The script always fetches `robots.txt` and `llms.txt`, resolves the sitemap (following a
sitemap index and decompressing `.xml.gz` if present), and — unless you pass
`--skip-wayback` — queries the Wayback Machine's CDX API for independent first-seen dates.
Use `--cdx-path-prefix` to scope that query to the site's actual content bucket (e.g. `guide`
or `blog`, read off `top_path_segments`) rather than the whole domain — an unscoped query
mixes in every page the domain has ever had, not just the content type you're measuring.

If you're comparing multiple sites (the common case — "how does X stack up against Y"), run
the script once per domain and keep the JSON outputs; don't re-derive by hand.

## Step 2 — Read what's deterministic, straight off the output

- **`robots_txt.named_ai_agents`**: which AI-crawler tokens the site names individually,
  vs relying on a wildcard `User-agent: *`. Naming agents individually is a deliberate act,
  not a default — but a named token only works if it's a *real, current* one. Anthropic and
  OpenAI have each added and occasionally renamed tokens; if `references/verifying-agent-
  tokens.md`'s sources disagree with what the script's `KNOWN_AI_AGENTS` list expects,
  update the script's constant, not just this note.
- **`llms_txt.present`** and its byte count: a proxy for how deliberately the site has
  written *for* a model to consume, distinct from writing for a person.
- **`sitemap.total_urls`**, **`top_path_segments`**, **`lastmod_by_month`**: raw scale and
  where the content lives. Treat `lastmod_by_month` as a claim, not a fact — see Step 3.
- **`crawler_access_matrix`**: does live behaviour match the stated policy? A `robots.txt`
  that disallows an agent but still serves it 200 is normal (robots.txt is a request, not a
  server-enforced block, for anything short of an edge rule). A `robots.txt` that *allows*
  an agent but the server 403s it anyway is the more interesting and rarer finding — it means
  the written policy and the actual policy disagree, and an agent reading only the file would
  be misled either way.
- **`wayback_first_seen`**: an independent crawl history, not the site's own claim about
  itself. `total_unique_urls` compared against the current sitemap total tells you how
  complete the Wayback sample is (it will almost always undercount — the crawler doesn't see
  everything, and doesn't see it immediately).

## Step 3 — The interpretation the script can't do for you

**Does `lastmod_by_month` actually mean what it looks like it means?** A site whose sitemap
`lastmod` shows a sudden spike (e.g. most pages dated in the last 4-8 weeks) is making an
implicit claim: "we created most of this recently." That claim has an alternative, mundane
explanation that produces an *identical* `lastmod` pattern: a site migration, CMS switch, or
template change bumps every page's modified-date at once, whether or not the content itself
changed.

**`lastmod` alone cannot distinguish these two stories. This is the check that can:**
compare `sitemap.lastmod_by_month` against `wayback_first_seen.first_seen_by_month` for the
same content bucket (use `--cdx-path-prefix` to scope them to match). Two outcomes:

1. **They agree** — Wayback's independent first-seen dates cluster in the same window as the
   `lastmod` spike. The growth claim holds up under a second source.
2. **They disagree** — Wayback shows most of the content already existed well before the
   `lastmod` spike window. This is real evidence for the migration/template-bump explanation,
   not proof of it (Wayback has its own lag and coverage gaps — a content *diff* between an
   archived snapshot and the live page is the next-level check if this matters enough to
   pin down exactly). Either way, don't report the `lastmod`-only growth number as settled
   once you've seen a disagreement like this — report both numbers and say what each one
   actually measures.

**What kind of site is this, really?** Don't infer a site's business model from the fact
that it publishes content about a topic. A page selling a product, a clinic that prescribes
it, a coaching programme that includes it, and a B2B vendor whose blog happens to mention it
are four different things with four different reasons to be findable — and that distinction
changes what a finding *means* (a B2B vendor's content showing up in a direct consumer
question's search results is a relevance problem, not just a "less aggressive at AI-SEO"
data point). Read `llms_txt.raw` if present (sites increasingly self-describe there in plain
language) and fetch an `/about` page if not — don't assume from the domain name or from
what a search engine snippet called it.

## Step 4 — Report it

State findings with their source and caveat attached, not as bare numbers:

- "X pages, per the current sitemap" (a fact) vs "X pages added in the last N weeks, per
  `lastmod`" (a claim, self-reported, cross-check before repeating it) vs "X pages Wayback
  independently confirms existed by date D" (a fact, but a lower bound — Wayback's sample is
  always partial).
- A `robots.txt` finding always needs "as of [date]" — this is live configuration, and
  re-checking before it's relied on again is cheap (one `curl`).
- Don't compare two sites' numbers without checking they're the same *kind* of number — a
  whole-domain page count against another site's single-content-type count isn't a fair
  stack-up.

## Known limitations of `audit.py`

- Sitemap index recursion is capped at depth 2 and 60 children per index file — enough for
  ordinary CMS output, not for adversarially huge sitemaps.
- The crawler-access test uses a fixed UA string per agent (see `DEFAULT_TEST_UAS` in the
  script) and a HEAD request falling back to GET. It shows what one network sees when it
  self-declares as an agent — not what any vendor's real infrastructure receives, and not
  whether the returned 200 is actually parseable content rather than an interstitial or a
  client-rendered shell.
- The Wayback CDX query can be slow (tens of seconds) on domains with a long crawl history;
  `--skip-wayback` if you only need the current-state checks.
- No JavaScript rendering anywhere in this script. A site that serves an empty shell to
  non-browser requests and hydrates client-side will look emptier here than it is to a
  browser — worth a manual spot-check if a site's crawler-test results look suspiciously
  thin against its apparent size.
