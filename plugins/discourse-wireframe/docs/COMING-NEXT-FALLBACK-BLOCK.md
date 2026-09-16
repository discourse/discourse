# Coming next — data-block fallback block

Roadmap for a generic **fallback block**: a way for any data-loading block to
render a chosen replacement when it can't show its data — because the data
resolved empty, or the fetch failed. Captures the motivation, the interim
per-block precedent, and the phased design so the sequence survives a lost
session. Nothing here has shipped yet.

## Motivation

Data-loading blocks resolve their content through the core `data` hook and
surface loading / empty / error through the four slots of the `<@Data>` boundary
(`frontend/discourse/app/lib/blocks/-internals/components/block-data.gjs`:
`:loading`, `:content`, `:empty`, `:error`). Today each block hand-writes its own
`:empty` / `:error` markup — a bare box, a neutral message, or nothing. That is:

- **Repetitive** — every data block reinvents an empty/error treatment.
- **Inflexible for the author** — the page builder can't say "if this featured
  topic can't load, show this callout / a different card instead."
- **Inconsistent** — no shared visual language for "there's nothing here yet".

A generic fallback block would let a data block delegate its empty/error state to
another block the author picks, instead of bespoke per-block markup.

## Interim precedent (shipped in the topic-card cycle)

The `topic-card` block established the block-local pattern this initiative would
generalize:

- Its resolver (`fetch-topic-card.js`) distinguishes **unconfigured** (resolves
  `null` → `:empty`) from **unavailable** (throws → `:error`).
- It renders a full-card `:loading` skeleton and a neutral `:error` message.
- A per-instance `hideWhenUnavailable` toggle lets the author choose "message" vs
  "render nothing" on failure.

That toggle is the minimal, block-local version of "pick what shows when the data
isn't there." The fallback block generalizes it from a boolean to "render this
block instead."

## Deferred phases (recommended sequence)

### P1 — Fallback slot contract in `block-data`
Give the `<@Data>` boundary an optional author-supplied fallback that the
framework renders for the `:empty` and/or `:error` slots when the block doesn't
override them. Decide the contract: is the fallback a nested block entry
persisted on the data block's args, a reference to a sibling block, or an inline
mini-layout? This is the load-bearing design decision — it touches the persisted
layout shape, so it becomes a contract. Keep the existing per-block `:empty` /
`:error` overrides working (fallback is opt-in).

### P2 — Editor affordance to choose a fallback
Inspector control (and/or on-canvas affordance) for picking the fallback block,
reusing the block picker the empty-cell / empty-container placeholders already
use (`editor-empty-drop-placeholder.gjs`). Distinguish "fallback for empty" from
"fallback for error" if P1's contract supports both.

### P3 — Migrate the built-in data blocks
Move `topic-card`, `featured-topics`, `recent-topics`, `featured-users`,
`featured-tags`, etc. onto the shared fallback path where it improves on their
bespoke `:empty` markup. Retire block-local one-offs (e.g. fold
`hideWhenUnavailable` into "no fallback configured → render nothing").

## Rationale for the order
P1 is the whole risk: the persisted contract for "what is a fallback" must be
right before any editor UI or block migration commits to it. P2 is inert without
P1. P3 is a mechanical sweep once the contract and editor exist, and it's where
the payoff lands (every data block gets consistent, author-controlled empty/error
treatment).

Each phase ships green (`bin/lint`, `pnpm build`, `bin/qunit`) and nothing lands
on the production render path without a passing test — the render path runs on
every production page.
