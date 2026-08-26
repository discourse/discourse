# Known limitations

## Code detection

Edge cases where the scanner knowingly diverges from what core renders. Every
entry falls back toward NOT code: the affected embed is still extracted and
rewritten, which at worst edits text inside something core shows as code —
never the other way around, which would drop the embed for good. Each entry is
pinned as a spec in `code_parity_spec.rb`'s "deliberate divergences" section.

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

## Internal link routes

- **Percent-encoded usernames** — `/u/j%C3%B8rn` is what a browser copies for
  the profile of a unicode user `jørn`. The route parser does not decode
  percent escapes, so the path is not read as a user route: an absolute URL
  falls back to a site reference (origin rewritten, path kept verbatim) and a
  relative one stays literal, instead of resolving to the user.
