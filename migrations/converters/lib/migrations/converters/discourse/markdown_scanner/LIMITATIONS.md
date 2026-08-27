# Known limitations

What extraction knowingly leaves undone. Nothing listed here edits text core
treats as code: the engine tier proves positions before rewriting and
otherwise leaves text verbatim, and the prose walk only runs on bodies the
gate proved free of context-sensitive syntax. The old line-oriented walk and
its divergence list are gone — every body they applied to now takes the
engine tier.

## Engine tier (context-sensitive bodies)

The `EngineScanner` parses with the real discourse-markdown-it engine.
Constructs it cannot place stay verbatim with stale references, all
fail-closed:

- **Unproven constructs stay verbatim and are reported.** Count certification
  refuses ambiguity; the trial pass then proves occurrences one by one by
  marker substitution and re-parsing, which also covers CR line endings and
  most entity-bearing bodies. What survives both — chiefly a construct the
  engine decoded out of a character entity (`&#64;bob` spells a mention no
  literal bytes can prove), or duplicate values whose every trial fails — is
  left unchanged, and the body is counted with its cause on
  `RawExtractor#engine_refusals`: the conversion's must-resolve list.
  Measured on a real corpus, certification alone already left well under 1%
  of engine-tier bodies; the trial pass reduces that further.
- **Unanchored link forms stay verbatim, without a refusal.** A proven
  destination whose surrounding syntax the detector grammar cannot take whole
  (a label with an escaped `]`, a destination beyond the pattern caps) keeps
  its source text; other constructs in the same body are still extracted.
- **Bare schemeless-domain links** (`forum.example.com/t/5`, which linkify
  links in core) are recognized by the engine but have no syntax anchor a
  detector can take, so they stay verbatim.
- **Trial budget** — a body gets at most 48 trial parses; occurrences beyond
  the budget stay unproven. Only a generated body full of duplicated tracked
  values can reach it.

## Prose walk (`:prose`-classified bodies)

By the gate's definition these bodies contain no code syntax, no link syntax,
no CR endings, and no construct-capable entities, so plain detector matches
are exact — the equivalence with the engine tier on this class is asserted by
spec against the real engine. What remains:

- **Pattern caps** — the detector and link-shield patterns cap their runs
  (link labels at CommonMark's 999 characters, destinations and bare URLs at
  2 KiB, quote headers at 512 bytes) so a body full of malformed openers
  scans in linear time. A construct beyond a cap is not matched — and for the
  bare-URL shield that means a longer URL is not skipped whole, so a
  construct-shaped string beyond 2 KiB inside one could be extracted. Real
  content does not approach the caps.

## Both tiers

- **The foreign-host signal** reports each host once per extractor, and does
  not consider a possible subdirectory prefix on the foreign host — a
  forgotten former domain that served the forum under `/forum` parses no
  route and stays unreported.

## Resolution (importer side)

- **A resolution miss restores the verbatim source.** Every embed row carries
  its exact matched substring; links additionally rewrite only the
  destination span inside it on a hit, so titles, angle brackets and padding
  survive. A canonical rebuild happens only when something actually resolved
  (a renamed quoted user produces a canonical `[quote="…"]` header) or for
  rows without a verbatim source.
