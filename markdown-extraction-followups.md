# Markdown extraction — follow-up work

Everything deliberately left out of the tiering PR (discourse/discourse#42990,
branch `mt/markdown-tiering`), with the reasoning, so nobody has to re-derive
it. Ordered roughly by when it should happen, not by size.

## 1. Posts converter step (the reason the scanner exists)

Revive the old posts step (#41949) as a new PR once #42990 merges: rebase
`mt/discourse-posts-step`, adapt it to the engine context, the tier gate and
`scan_batch` batching, and give `RawExtractor` its first production caller.
Everything below that says "posts step" belongs in or beside that PR.

Also needed there:

- `LOAD_PLUGINS=1` for the migrations rails CI job, so the parity specs run
  against the bundled plugins.
- Decide the harness's fate: absorb its all-miss round-trip check into a spec,
  or delete the script. It currently lives on `mt/markdown-validation-tooling`
  and untracked in the tiering worktree — remove that untracked copy when the
  loop closes.

## 2. Prepared-body / batch API

Raised in the fifth, sixth and seventh review passes. The intended workflow
calls `engine_bound?`, scans the selected bodies, then calls
`extract(scan_data:)` — and the first and last both normalize and classify the
same body. `scan_batch` also has no aggregate byte cap, so the caller has to
bound both post count and bytes.

A prepared-body API would remove the duplicate work and put both limits in one
place. Deliberately not designed yet: with no production caller, the shape
would be guesswork. Design it against the posts step's real loop.

## 3. Importer lookup scaling

The resolver's slug and bind-parameter lookup paths were flagged in several
review passes as large-map performance items. Not correctness, not scanner
work — they belong to the import side, where the maps get big.

## 4. Split `placeholder_resolver.rb`

834 lines with a real seam: batch id resolution (`resolve_all` …
`resolve_hashtags`, ~320 lines) versus rendering (`render` … `render_emoji`
including the destination-span splicing, ~390 lines). The specs already split
exactly that way — `id_resolution_spec.rb` and `substitution_spec.rb` against
`rendering_spec.rb` and `links_spec.rb` — which is the evidence the seam is
real.

Not done in the tiering PR on purpose: the file pre-existed on main at 613
lines, so moving it would read as a rewrite of code that PR only extends. The
posts step touches the resolution half anyway (see item 3), so do it there.

## 5. Uploads inside raw HTML — measured, worth doing

Counts over the corpus (1,616,062 posts):

| what | posts | share |
| --- | --- | --- |
| `<img>` with an upload `src` | 22,591 | 1.40% |
| … of those, in posts with no code fence at all | 21,986 | 97% of them |
| spelled `upload://…` | 22,470 | — |
| spelled `/uploads/…` | 122 | — |
| spelled with an absolute source-host URL | 0 | — |
| internal `<a href>` outside fences | 1,522 | 0.094% |

So this is real user content, not code samples, and it is about short URLs —
there is no dead-host origin problem here. For comparison, the extractor's
whole refusal rate is 0.194%.

Today these are invisible rather than refused: markdown-it emits
`html_inline`, `scan.js` only collects link and image tokens, so a post whose
only construct sits in a raw tag reports no blocks at all. They never show up
in the refusal tally.

**The engine already finds them.** Core's
`frontend/discourse-markdown-it/src/features/upload-protocol.js` runs
`findUploadsInHtml` over html tokens (core's own xss filter, matching `img` +
`src`) and passes every `upload://` value to Ruby through `lookupUploadUrls`.
Verified against our own bundle: parsing
`<img src="upload://abc123.png"> and ![x](upload://def456.png)` calls
`__Ruby.lookup_upload_urls` with both values. Our `runtime.js` stubs that
method with `{}` and drops them.

So the work is mostly "stop discarding what the engine found": collect the
per-post list in `runtime.js`, surface it in `scan.js`, let those values join
the upload set for count matching. `upload://<base62>.<ext>` appears verbatim
in the raw, so the existing locating machinery positions it — anchor on the
value, the way `UploadUrl` does for bare URLs. No HTML grammar of our own, and
the attribute parsing is done by the same code the destination runs.

Open questions for whoever builds it:

- Core's helper matches only `img` + `src`, so raw `<a href="upload://…">`
  attachments stay invisible. Probably tiny; measure before caring.
- A value appearing both in a code block and in a raw tag escalates to
  substitution — check the delta logic copes with an `html_inline` token whose
  content changed.
- Severity is bounded: short URLs are content-derived (base62 of the sha1), so
  an identically re-uploaded file keeps the same `upload://` and renders
  anyway. The break case is a destination upload with a different sha1, or one
  that never imported. Confirm against how the importer assigns sha1s before
  ranking this item.

## 6. Internal links inside raw HTML — probably not worth it

1,522 posts (0.094%), half the refusal rate, and unlike the upload case there
is no ready-made extraction in core to reuse: `upload-protocol.js` only looks
at `img`/`src`. It would need a real grammar for `<a … href=…>`.

If it is ever built, two notes:

- **Do not use Nokogiri in the extraction path.** It decodes attributes
  (`href="…a&amp;b…&quot;y"` comes back as `…a&b…"y`) and offers no column
  positions. That is the normalized-spelling class that produced 10 and 75
  corpus violations in the two rejected experiments. Core can use Nokogiri in
  `Post#each_upload_url` because it only reads cooked HTML to find ids, never
  writes bytes back into a post. Nokogiri as a spec-side oracle is fine.
- markdown-it's `html_inline` token content is the author's exact bytes,
  entities intact, so the engine can supply both the raw spelling and a decoded
  value — the same split as `InternalLink#reference_for(route_url:, url:)`.

`Post#each_upload_url` also names the full attribute surface, if we ever go
wider than `img`: `a/@href`, `img/@src`, `source/@src`, `track/@src`,
`video/@poster`, `div/@data-video-src`, `div/@data-original-video-src`.

## 7. Things reviewed and deliberately left alone

So they don't get re-opened:

- **The S3 upload gate** can enter V8 when `original/` or `optimized/` and an
  unrelated `//` sit in different parts of one post. Correctness-safe, and
  tightening it measured +1.1pp engine tier. Keep the simple gate unless
  corpus numbers move.
- **`internal_link.rb` (420 lines)** is one class whose bulk is regex
  constants with the comments explaining why each branch rejects ordinary
  words. `RouteParser` is already separate. Splitting grammar from construct
  would separate the rules from their reasons.
- **Files whose "second class" is a value or error type** — `Bundle::BuildError`,
  `MarkdownRenderer::UnknownFormat`, `Locating::Occurrence`,
  `EngineScanner::Result` / `RetryDeadlineError`, the resolver's
  `UnresolvedEmbed` / `OrphanPlaceholder`. Those belong with their owner.
- **`TierGate`'s unknown-construct fallback**, `on_foreign_host`,
  `CompactStringSet#size`, and `Config#additional_options` all survived the
  overengineering sweep for stated reasons (a future construct must cost an
  engine parse rather than be silently skipped; the posts-step branch passes
  the foreign-host lambda; the dedup specs need `size`; the parity spec feeds
  real host options).
- **Optional slug+id rendering for topic links** needs destination slugs in the
  mapping surface; parked until someone wants it.
