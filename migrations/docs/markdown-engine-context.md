# Markdown engine context (tiered scanner, PR 1)

The tiered markdown-scanner design sends every post holding a candidate
construct (as built, roughly 40% of posts on a measured corpus — the rest
skip extraction entirely) through the real `discourse-markdown-it` engine
instead of a hand-written Ruby grammar. This document designs the piece
everything else depends on: a **self-contained engine context** the converter
can run per worker — without a booted Rails application, a migrated local
site database, or any ambient site state.

Benchmarks for the overall approach live in
`migrations/tooling/scripts/benchmarks/markdown_engine_bench.rb`; that script
borrows PrettyText's context from a booted Rails app, which is exactly the
dependency this design removes.

## Goals

- Parse markdown with the same engine, features, and options the target site
  will use to cook the migrated posts, so scan results are correct by
  construction rather than by imitation.
- One V8 context per converter worker process, created after fork, usable for
  the whole run.
- All configuration comes from explicit inputs: the source database and
  converter settings. Nothing is read from a local Discourse site.
- Parse-only. The context never renders HTML, never sanitizes, never resolves
  avatars or topic titles.

## Non-goals (later PRs)

- The tier gate, bijection certification, and trial-substitution fallback
  are separate PRs; this PR only delivers the context plus a `scan` call
  returning per-post token data.
- V8 snapshot optimization. Context creation happens once per worker; the
  measured cost of full evaluation is acceptable (~hundreds of ms).

## What PrettyText's context actually consists of

From `lib/pretty_text.rb` (`create_es6_context`) and `lib/pretty_text/shims.js`,
a working engine context is:

1. **Vendor libraries** loaded verbatim from checked-in node_modules:
   `loader.js`, `markdown-it`, `xss`, plus `lib/pretty_text/vendor-shims.js`.
2. **Transpiled application modules**: `frontend/pretty-text/addon/**`,
   `frontend/discourse-markdown-it/src/**`, and a small fixed list of
   `frontend/discourse/app` helpers — each run through `AssetProcessor`.
3. **Plugin markdown features**: every plugin's
   `assets/javascripts/**/discourse-markdown/**` files, transpiled the same
   way.
4. **Static data**: `__setUnicode(Emoji.unicode_replacements_json)` — built
   purely from the static emoji db, site-independent.
5. **Ruby-attached callbacks** (`__helpers.*`) used by `shims.js`.
6. **Per-cook options** (`__optInput`): site settings, custom emoji, watched
   words, hashtag type order, etc., followed by
   `__DiscourseMarkdownIt.withCustomFeatures(...).withOptions(...)`, which
   yields the engine instance whose `parse(markdown, env)` returns the token
   stream.

Only items 5 and 6 touch a live site. Items 1–4 need the Discourse checkout
and its installed frontend dependencies, which the converter already runs
inside.

## Design

### Bundle: transpile once, in the parent

`Migrations::Converters::MarkdownEngine::Bundle` produces the full list of
`[module_name, javascript_source]` pairs for items 1–3 above, in load order.

- Transpilation reuses `AssetProcessor` directly. It runs in its own V8
  context, caches its compiled processor on disk keyed by an input digest,
  and needs `pnpm`/`node` only on a cache miss. Its host-constant
  dependencies (`Rails.root`/`Rails.logger`, `GlobalSetting`, and
  `Discourse::Utils` on a processor-cache miss) are satisfied by
  `MarkdownEngine::HostShims`: minimal stand-ins installed only when the
  constants are absent, so a booted application (the parity specs) is
  untouched. One ordering constraint: `discourse-emojis` gates its railtie on
  `defined?(Rails)`, so the gem must load before the `Rails` stand-in exists.
- The bundle is cached on disk under `tmp/` keyed by a digest of the input
  files (same pattern as `AssetProcessor`'s own cache), written via lock +
  temp file + atomic rename, and a cold build runs in a **throwaway
  subprocess**: transpiling boots `AssetProcessor`'s V8, and multithreaded V8
  is not fork-safe — the converter parent forks workers, so it must never
  hold V8 state (nor the host stand-ins the transpiler needs). The parent
  only computes the digest and reads JSON; workers only `eval` cached
  sources. Cold builds therefore need node once per checkout state; warm
  runs need nothing.
- Plugin features: the bundle includes the markdown features of the
  **core-bundled plugins** — the explicit list is `chat`, `checklist`,
  `discourse-details`, `discourse-local-dates`, `footnote`, `poll`,
  `spoiler-alert` (a dev checkout can contain many more plugins; the target
  site cooks with exactly these). Rationale: constructs they claim (e.g.
  `[poll]`) must tokenize the way the target will see them — otherwise text
  inside a poll would be scanned as ordinary prose. Their
  `:vendored_pretty_text`/`:vendored_core_pretty_text` assets (moment,
  moment-timezone, markdown-it-footnote) are bundled verbatim, mirroring the
  registry evals PrettyText performs. Third-party plugin features are out of
  scope until a converter needs one.

### Context: one per worker, created after fork

`Migrations::Converters::MarkdownEngine::Context` wraps one
`MiniRacer::Context`.

- Created lazily in a worker's step `setup`, never before fork (V8 contexts
  do not survive forking). A `ForkManager.after_fork_child` hook discards any
  accidentally inherited instance, mirroring the Postgres adapter.
- Single-threaded use only; workers are processes, so no mutex is needed
  beyond mini_racer's own requirements.
- Construction evals: vendor libs → cached transpiled modules → static emoji
  data → replacement shims (below) → options → engine instance → the scan
  function. Then `low_memory_notification` to shed init garbage.

### Callbacks: replace `shims.js` bindings with scan-mode implementations

The context does not attach Ruby procs. Each `__helpers` consumer gets a
pure-JS replacement, injected as data at construction time — fork-safe, no
Ruby round-trips during scanning:

| PrettyText binding | Scan-mode behavior | Why |
|---|---|---|
| `hashtagLookup` | JS map lookup over **source** category slugs and tag names, returning a minimal resolution record (`text` is required — it becomes a token's content — and `ref` must preserve the typed form including a `::type` suffix, like the host service) | Unresolved hashtags don't tokenize usefully; resolving against the source names makes `#slug` produce tokens exactly when the slug is real on the source |
| `lookupUploadUrls` | Always returns no resolutions | Leaves `upload://` values in `data-orig-src`/`data-orig-href`, which the token walk reads |
| `getTopicInfo` | Returns nothing | Only affects rendered quote titles |
| `lookupAvatar`, `lookupPrimaryUserGroup`, `formatUsername` | Inert identity/no-op stubs | Render-time concerns |
| `getCurrentUser` | Returns nothing | Cook-time personalization does not exist during migration |
| `t` (i18n) | Returns the key | Deterministic; translated strings never reach the token data the walk extracts |
| `getURL`/CDN paths | Identity | No CDN during scanning |

Custom emoji names come from the source database (`custom_emojis` equivalent
in the source data) with a placeholder URL — the walk needs names, not CDN
paths.

### Options: derived from the source, explicit and versioned

`__optInput.siteSettings` is built from the checkout's YAML defaults
(`config/site_settings.yml` plus the bundled plugins' `settings.yml`)
overridden by the **source site's own settings** for the keys the markdown
JavaScript reads (`Config::SETTING_KEYS` — `enable_mentions`,
`unicode_usernames`, linkify/typographer settings, emoji settings, plugin
toggles, …). The authoritative inventory is every `siteSettings.*` reference
in the JavaScript the bundle loads, and a spec greps exactly those files and
asserts each key is classified, so upstream additions fail loudly here
instead of silently falling back to `undefined` in V8.

Deliberate defaults rather than source values:

- **Watched words** (censor/replace/link): empty. They are cook-time
  transformations of the *target* site, unknown at conversion time; the
  target's defaults are empty.
- **`allowedIframes`**, avatar sizes, hashtag icons: render-time only;
  static defaults.
- **Hashtag type priority**: static `["category", "tag"]` — the composer
  ordering the target uses by default.

### The scan entry point

Construction ends by evaluating a `scan.js` (ported from the benchmark's
walk, which three corpus rounds have debugged) that exposes:

```js
__scanPosts(posts)  // [{id, raw}] → per-post block/construct data
```

returning, per post: block-level tokens with line maps (quotes, code, html
blocks — a quote's map lives on the inner `blockquote` bbcode token, the
outer `aside` has none, so any mapped bbcode token is recorded with its tag),
and per inline block the recognized construct values (mentions, emoji names,
link hrefs and image srcs — preferring `data-orig-*` attributes, excluding
fragment-only hrefs — and hashtags as `{type, slug}`, since the href shape
depends on lookup internals the scan replaces), compact JSON only, never
token trees. The Ruby side batches posts per call (byte-bounded batches; the
benchmark showed batching matters mostly for tail latency).

### Ruby API sketch

```ruby
bundle = MarkdownEngine::Bundle.load_or_build        # parent, once
config = MarkdownEngine::Config.new(                 # explicit inputs only
  source_settings:,                                  # parse-relevant subset
  category_slugs:, tag_names:, custom_emoji_names:,
)

# per worker, in step setup:
engine = MarkdownEngine::Context.new(bundle:, config:)
engine.scan(posts)   # => per-post construct data for the bijection stage
```

## Testing

- **Unit specs** for `Bundle` (cache behavior, digest invalidation) and
  `Context` (construction, scan output shape) — no Rails, tagged normally.
- **Parity spec (`:rails`)**: the acceptance test for the whole design. Feed
  a fixture corpus through (a) this context and (b) PrettyText's own booted
  context, and assert identical scan output. Any callback or option we
  stubbed wrongly shows up as a diff here. This reuses the existing parity
  harness precedent and runs in the Rails integration job.

## Open questions / decisions to confirm

1. **mini_racer as a converters gem dependency** — added unpinned, following
   the host Gemfile (which is also unpinned); same for `discourse-emojis`.
2. **Cold-start node requirement**: environments running a converter on a
   fresh checkout need `pnpm install` + node once for the AssetProcessor and
   bundle caches. Document in the converter README; consider shipping warmed
   caches in the container image.
3. **Typographer**: it rewrites text-token content (quotes/dashes), which is
   fine for construct values but worth a parity-spec case to prove the
   bijection counting is unaffected.
4. **Per-worker memory**: one V8 isolate per worker (~tens of MB). Measure
   RSS with the converter's usual worker count before choosing defaults.
