# Verifying AI-crawler user-agent tokens

`scripts/audit.py`'s `KNOWN_AI_AGENTS` list is a snapshot, not a guarantee. Vendors add
tokens and occasionally rename them. Before treating an absence from that list as meaningful
(e.g. reporting "this site doesn't name Claude's live-retrieval agent"), check it's still
correct:

- **Anthropic**: publishes its current crawler user-agents and IP ranges in its own docs.
  Search for "Claude" + "robots.txt" / "user agent" on Anthropic's current documentation site
  rather than trusting this file's memory of it.
- **OpenAI**: publishes `GPTBot`, `ChatGPT-User`, and `OAI-SearchBot` (distinct roles —
  training-crawl, live-fetch-on-request, and search-index) in its own platform docs.
- **Perplexity, Google, Common Crawl, Meta, Apple, Amazon, ByteDance, Cohere**: each
  publishes its own token(s) similarly; search each vendor's current docs rather than a
  third-party aggregator, which lags.

A site's `robots.txt` naming a token that *looks* plausible but is wrong (misspelled,
outdated, or a token the vendor never used) is a real finding worth reporting — it means the
site's evident intent ("we want this agent in") doesn't actually take effect, silently. That
was caught once already: a site's `robots.txt` named `Anthropic-User-Agent`, not the string
Anthropic's own docs and another site's correctly-configured `robots.txt` both used. Don't
assume a named-looking token works; check it against the current source before reporting the
site as having "opted in."

If you find `KNOWN_AI_AGENTS` in `audit.py` is stale, update it there — this file is guidance
for verifying, not a second copy of the list to maintain in parallel.
