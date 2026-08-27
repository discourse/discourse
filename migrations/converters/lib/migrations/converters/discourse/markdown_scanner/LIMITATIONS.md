# Known limitations

What extraction knowingly leaves undone. Nothing listed here edits text core
treats as code: the gate only decides whether a body holds any candidate at
all, and every body that does takes the engine tier, which proves positions
before rewriting and otherwise leaves text verbatim.

## Engine tier (every body with a candidate construct)

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
- **Pattern caps** — the detector patterns that parse a proven construct's
  syntax cap their runs (link labels at CommonMark's 999 characters,
  destinations and bare URLs at 2 KiB, quote headers at 512 bytes) so a body
  full of malformed openers scans in linear time. A construct beyond a cap
  cannot be anchored and stays verbatim. Real content does not approach the
  caps.
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
