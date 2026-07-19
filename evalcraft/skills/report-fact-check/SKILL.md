---
name: report-fact-check
description: Fact-check the findings in an eval report against ground truth — verify factual claims against primary sources and verify quoted model completions verbatim against the Inspect eval logs.
model: sonnet
---

# /evalcraft:report-fact-check

Use this skill to independently verify the claims in an eval-run report before it is
treated as reviewed. A finding in these reports makes two kinds of checkable claim, and
both must be verified from source, never from memory:

1. **Ground-truth claims** — statements about the world the finding leans on ("the
   trial was published in NEJM," "the spec has no such rule," "no such figure was ever
   published"). Verify against the primary source appropriate to the domain (PubMed,
   registries, official documentation, the project's verified reference data).
2. **Channel claims** — statements about what a model said ("model X said £6,000 in
   epoch 1," "model Y declined all three epochs"). Verify **verbatim** against the
   Inspect `.eval` logs the report was built from.

The point of the skill is that a report reader should be able to trust every quoted
number and every attributed quote. A single mis-transcribed figure or a mis-verified
citation undermines the whole instrument.

## Before you start

- Confirm which report you are checking and find its **log manifest** — the report
  should list the `.eval` file per model and the archive directory. If there is no
  manifest, stop and ask — you cannot verify channel claims without knowing which log
  maps to which model.
- Note the report's **source register** — the list of citations, IDs, and reference
  pages the findings lean on. That is your ground-truth checklist. If the report has
  none, building one is the first finding.

## Step 1 — Enumerate the checkable claims

Read the report and, per finding, extract every claim that is checkable against a
source. Split them into ground-truth vs channel. Typical checkable claims:

- A citation: source, year, identifiers.
- A specific documented result — or the **absence** of one ("no such figure exists").
- A quoted model completion (a figure, an identifier, a verbatim sentence) attributed
  to a specific model + sample + epoch.
- A quantitative meta-claim about a completion ("500+ words," "never mentions safety,"
  "a different number every epoch").

## Step 2 — Verify ground-truth claims

For each cited source, verify the citation details and the claimed fact against the
primary source itself — read the abstract/summary/section, don't trust the report's
paraphrase or your own memory. Note per claim: confirmed, overstated, or wrong, with
the source link. Respect source attribution terms (e.g. cite PubMed with DOI links
when using its data).

### Absence claims and false-premise probes — the highest-risk category

A finding that rests on *"no such figure/fact exists"* (a false-premise probe, a "the
model fabricated this") is the easiest to get wrong, and getting it wrong inverts the
whole finding's severity. The classic failure: checking only the **index source** (the
primary trial, the main spec), finding it indeed carries no such figure, and treating
that as confirmation — when the figure really exists in **derivative** literature
(follow-up analyses, models built on the index source, secondary documentation) at a
different scope or horizon.

To confirm an absence claim, the index source is **necessary but not sufficient**:

- **Search the derivative literature, not just the index source.** Derivative analyses
  routinely report figures the index source doesn't, over *different time horizons or
  framings*. Only "checked the index source **and** searched for derivative material
  and found none" supports an absence finding.
- **Variance across runs is not proof of fabrication.** "A different number every
  epoch" reads like the strongest fabrication signal, but different numbers can be
  *correct answers to different implicit horizons or framings*. Before classifying
  inter-epoch variance as fabrication, map each variant to a source: if each checkable
  figure matches a real analysis for the scope it names, the finding is a
  labelling/sourcing weakness, not a fabrication. Only variance where *no* variant maps
  to any real figure is a fabrication signal.
- **Downgrade the reason, not just the severity.** When a finding flips, the residual
  finding is usually real but different in kind: loose scope labelling, misattribution,
  an invented split. State that explicitly so the downgrade is auditable.

## Step 3 — Verify channel claims (Inspect eval logs)

Read completions from the `.eval` logs with the idiomatic Inspect API — **not** raw
`unzip` (`unzip -p` silently returns empty on these archives' compression method;
don't fight it):

```python
from inspect_ai.log import read_eval_log

log = read_eval_log(path)          # path to one model's .eval file
print(log.eval.model)              # confirm log→model mapping
for s in log.samples or []:
    if s.id == "<sample-id>":      # the probe the finding is about
        print(s.epoch, s.output.completion)
```

Then:

- **Confirm the log→model mapping** against the report's manifest before trusting any
  quote — `log.eval.model` is authoritative. A swapped mapping would attribute the
  right quote to the wrong model.
- **Diff each quoted figure/sentence verbatim** against `s.output.completion`. Report
  exact matches as ✅ and any drift (even a changed range or rounded number) as a
  required edit.
- **Recompute quantitative meta-claims in code** rather than eyeballing: word counts
  (`len(re.findall(r"\S+", text))`), and "never mentions X" via a term scan over a
  term list you state in the writeup. Report the actual numbers.

## Step 4 — Report discrepancies and edit

- Produce a per-finding verdict table: each checkable claim → ✅ confirmed /
  ⚠️ overstated / ❌ wrong, with the source.
- For anything wrong or overstated, propose the exact edit (old → new) and, once the
  user agrees (or for clearly-correct fixes like a mis-stated word count), apply it
  with `Edit`.
- Note any claim you **could not** verify explicitly — do not silently pass it.
- If verification surfaces a *stronger* framing than the report uses, flag it as an
  optional improvement — but the framing must survive the absence-claim checks above.
  A "pattern-completion not retrieval" argument is only valid once you have confirmed
  *no* variant maps to a real figure.

## Output quality checklist

Before finishing, verify:
- [ ] Every citation in the report's source register checked against its primary source
- [ ] Every claimed result checked against the source's actual text
- [ ] Every claimed **absence** checked against the index source **and** a search of
      the derivative literature — never asserted from the index source alone
- [ ] Any "different number every run = fabrication" claim confirmed by mapping each
      variant to sources and finding that *no* variant matches a real figure/scope
- [ ] Log→model mapping confirmed via `log.eval.model` before quoting
- [ ] Every attributed model quote diffed verbatim against `s.output.completion`
- [ ] Every quantitative meta-claim (word counts, "never mentions X") recomputed in code
- [ ] Unverifiable claims called out explicitly, not passed silently
- [ ] Edits proposed (old → new) for every discrepancy; applied once agreed
