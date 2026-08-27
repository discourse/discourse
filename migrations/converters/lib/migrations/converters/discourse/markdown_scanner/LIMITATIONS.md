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
- **Unanchored link forms stay verbatim and count as refusals.** A proven
  destination whose surrounding syntax no grammar can take whole (a label
  with an escaped `]`, a construct beyond the pattern caps, a pipe-less
  `[label](upload://…)` link — core links it, but the shape is unmeasured
  in real corpora and the pipe-bearing paste leftover is the one that
  actually occurs) keeps its source text and puts the body on the tally
  (`:unanchored`); other constructs in the same body are still extracted. A destination that is its own syntax —
  a bare schemeless domain linkify links, a reference definition's URL — is
  rewritten in place, not refused. An internal URL whose path opens a
  coordinate route but parses none (`/t//209`, `/u/bob!!!`, a slug-only
  `/t/<slug>` topic link — the intermediate DB carries no topic slugs to
  resolve one against) also refuses: an origin-only rewrite would carry its
  stale-looking ids onto the new host, which is worse than a reported
  verbatim link.
- **Multi-tag routes map whole or not at all.** `/tags/c/…` (category + tag,
  with an optional `none`/`all` subcategory filter) and
  `/tags/intersection/…` name several records; the importer rebuilds the
  route only when the category and every tag map, and any miss restores the
  verbatim source (reported). A trailing all-numeric segment is core's
  canonical tag-id ambiguity and refuses instead of guessing a reading.
- **A quote header the grammar cannot parse** (beyond the header cap,
  malformed) counts as a refusal too; a header that parses but carries no
  username has nothing to remap and is skipped exactly.
- **Trial budgets** — a body gets at most 48 trial parses and a bounded
  amount of trial wall-clock; occurrences beyond either stay unproven and
  the body reports `:trial_limit` / `:trial_budget`. Only a body full of
  duplicated tracked values (or one that is already pathological to parse)
  can reach them.
- **A per-body engine failure** (a parse timeout, a JS exception some body
  triggers) gets one patient retry under a slow ceiling (60s by default)
  before the body lands verbatim on the tally (`:engine_error`) with the
  engine context rebuilt for the next body. A body that only parsed on the
  retry is extracted and counted separately (`RawExtractor#slow_parses`) —
  it will cook just as slowly on the destination site.
- **Third-party plugin markdown is an accuracy boundary.** The engine loads
  the markdown features of the core-bundled plugins (their constructs must
  tokenize the way the destination cooks them — asserted by the plugin
  parity fixtures); a source that relied on some other plugin's markdown
  feature is scanned without it, so text inside such a construct is treated
  as ordinary prose.
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
- **Foreign-host upload URLs map only against an allowlist.** A full upload
  URL on a host the conversion did not recognize as the source's own carries
  that host on its row, and the importer maps its sha1 only when the
  conversion vouches for the host (`external_upload_hosts:` — an old CDN or
  S3 bucket). Any other foreign row is restored verbatim: a foreign 40-hex
  basename colliding with a source upload sha1 must not rewrite another
  site's file.
