# Known limitations

What extraction knowingly leaves undone, per tier. Since the engine tier
exists, no listed case edits text core treats as code the other way around:
the engine path proves positions before rewriting and otherwise leaves the
body verbatim, and the line-oriented walks only run on bodies the gate proved
free of context-sensitive syntax.

## Engine tier (context-sensitive bodies, with an engine context)

The `EngineScanner` parses with the real discourse-markdown-it engine, so the
divergences listed for the line-oriented walk below do not apply here. What it
gives up instead, all fail-closed:

- **Refused bodies stay verbatim.** A body whose constructs cannot be
  count-certified — the same tracked value ambiguously present in prose and
  code, a construct-capable character entity near a construct, CR line
  endings, a reference definition shared by several links — is left unchanged
  and the refusal cause is recorded (`RawExtractor#engine_refusals`). Its
  references stay stale until a later exact pass takes it. Measured on a real
  corpus, this is well under 1% of engine-tier bodies.
- **Unanchored link forms stay verbatim, without refusing the body.** A
  certified destination whose surrounding syntax the detector grammar cannot
  take whole (a label with an escaped `]`, a destination beyond the pattern
  caps) keeps its source text; other constructs in the same body are still
  extracted.
- **Bare schemeless-domain links** (`forum.example.com/t/5`, which linkify
  links in core) are recognized by the engine but have no syntax anchor a
  detector can take, so they stay verbatim.

## Line-oriented walk (no engine context, or `:prose`-classified bodies)

A `:prose` body contains none of the syntax below by the gate's definition,
so these apply only when extraction runs without an engine context. Every
entry falls back toward NOT code: the affected embed is still extracted and
rewritten, which at worst edits text inside something core shows as code.
Each is pinned as a spec in `code_parity_spec.rb`'s "deliberate divergences"
section.

- **Unregistered bbcode tags** — plugins can register block bbcode tags the
  scanner cannot know about. A line opening any `[foo]`-shaped tag is read as
  ending the paragraph, so an inline code span opened above it does not form
  and everything after it stays detectable. Core may keep such a span as code.

- **HTML blocks other than `<pre>`** — the scanner cannot tell CommonMark's
  HTML block type 6 (a known block tag, which interrupts a paragraph) from
  type 7 (any other tag, which does not). A line opening any tag is read as
  ending the paragraph, with the same span effect as above.

- **Closing HTML tags** — the same, for a line starting with a `</…>` tag.

- **Tables** — not modelled in the block phase; a delimiter row only bounds
  inline spans. A table interrupting a paragraph leaves the paragraph open, so
  an indented line directly below the table reads as prose where core reads
  indented code.

- **Pattern caps** — the detector and link-shield patterns cap their runs
  (link labels at CommonMark's 999 characters, destinations and bare URLs at
  2 KiB, quote headers at 512 bytes) so a body full of malformed openers
  scans in linear time. A construct beyond a cap is not matched — and for the
  link shield that means a longer destination is not skipped whole, so a
  construct-shaped string beyond 2 KiB inside one could be extracted. Real
  content does not approach the caps.

## Both tiers

- **The foreign-host signal** reports each host once per extractor, and does
  not consider a possible subdirectory prefix on the foreign host — a
  forgotten former domain that served the forum under `/forum` parses no
  route and stays unreported.
