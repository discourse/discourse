# i18n for editable text in block layouts

## Context

The wireframe editor lets admins author text inside blocks (headings, paragraphs, button labels, callouts — all `richInline` args). Today that text is stored *literally* inline in each block entry's `args` (a plain string or ProseMirror doc-JSON), and `ApplicationLayoutPreloader#theme_block_layouts_json` serves **one layout to every visitor regardless of locale** — no locale awareness exists anywhere in the blocks path. A multilingual site can only show one language of authored copy.

Discourse's existing i18n machinery doesn't fit directly: translation overrides and theme translations store **plain, sanitized strings** (flattening rich doc-JSON), and content localization is a per-record DB-table pattern unrelated to layouts.

**Decision (confirmed):** support **two complementary mechanisms** behind one core resolution chokepoint.

1. **Inline per-locale variants (Mode 1)** — translations stored in the same layout JSON, rich doc-JSON preserved, edited in the wireframe editor via a locale switcher. For **site admins translating their own content**. Self-contained per layout; matches the configurable-instance / in-place-overrides model.
2. **Theme i18n key references (Mode 2)** — a text arg can hold a `{ "$t": "key" }` reference resolved against the theme's translation namespace, with strings in `locales/*.yml`. For **theme developers shipping layouts from a git repo** translated externally (Crowdin). **Keys may also be defined/authored from the editor** (see §5), so Mode 2 works for admin-created themes too and exports to a repo on theme export.

An arg value is either a literal (optionally with inline per-locale variants) **or** a `{ $t }` reference; never both.

### Storage shapes

**Mode 1** — each entry gains an optional `i18n` map, keyed by arg path (mirroring the dot-delimited `overrides` convention), values are per-locale copies of the arg value:
```jsonc
{ "block": "heading",
  "args": { "text": { "type": "doc", "content": [/* "Welcome" */] } },
  "i18n": { "args.text": { "fr": { /* doc "Bienvenue" */ }, "de": { /* doc "Willkommen" */ } } } }
```
Missing locale → fall back to base `args` → schema default.

**Mode 2** — the arg value is a reference; the strings live in the theme's `locales/<locale>.yml`:
```jsonc
{ "block": "heading", "args": { "text": { "$t": "block_layouts.home.hero.title" } } }
```

### Scope of localization
v1 localizes **top-level text args** (`richInline` / string). Composite per-part overrides (`entry.overrides[path][arg]`) and non-text args are out of scope (follow-up). The path-key schemes don't collide — Mode 1 uses `entry.i18n["args.X"]`, overrides use `entry.overrides["<partPath>.X"]`, distinct fields (verified `composite.js:96-108`).

## Why these seams (and what the review corrected)

The architecture exposes the right hooks, but the adversarial review (4 lenses, code-cited) found the first draft would silently fail in several places. Corrections are folded into the design below; the load-bearing ones:

- **`entry.themeId` is NOT on block entries.** It's stamped on the *layer wrapper* (`block-outlet.gjs:617-619`) and dropped at the render boundary (`:1038`); nothing in `lib/blocks/` reads it. Mode 2 must get `themeId` **threaded through the render context** into the getter, and re-stamped on the `SESSION_DRAFT` layer (`block-outlet.gjs:764` only stamps the THEME layer) or the editor can't preview keyed args.
- **The arg getter closes over a shallow `{...entry}` spread** taken at curry time (`entry-processing.js:113`). `entry.i18n` must be **always materialized** (an empty tracked object, like `args`) or a translation added after curry time renders stale.
- **`resolveLocalizedArg` must use keyed reads only** — any `Object.keys`/spread/`for…in`/`Object.entries` on the i18n map consumes the `trackedObject` collection tag (`@glimmer/validator:631`), which `set` dirties (`:633`), re-currying every container on every keystroke (the hazard `block-outlet.gjs:219-228` warns of). The `fr_CA→fr` fallback is two explicit keyed reads. (Consequently the `__argKeys`-style snapshot is **not** needed for `i18n`.)
- **The cache guard** `shallowArgsEqual(cachedEntry.args, entry.args)` (`entry-processing.js:88`) is intentionally **not** extended to `i18n`; extending it would force destructive re-currying. Value updates ride the compute-ref re-pull, exactly as base-`args` edits do today.

Confirmed safe (no change): server `bake_block_layout!` / `validate_block_layout_entries!` pass `i18n` and `{$t}` through untouched (`theme_field.rb:402-417,545-585`); the preload payload is locale-agnostic so client resolution is correct with no per-locale double-cache (`application_layout_preloader.rb:181-186`); `theme_translations.{id}` is loaded client-side for the whole active stack incl. children (`theme.rb:456,577-583`, `discourse-i18n/src/index.js:530-538`); `I18n.currentLocale()` reflects the visitor's locale for anon and logged-in (`application_controller.rb:428-448`, `discourse-i18n/src/index.js:42-44,467`).

> **Core stays plugin-agnostic.** All core additions describe generic "per-locale arg resolution." The live site renders via core (the editor isn't loaded there), so resolution must live in core.

## Implementation

### 1. Core — per-locale resolution (live render path)

**New module `frontend/discourse/app/lib/blocks/-internals/locale.js`** (mirrors `arg-renderers.js`):
- A **dedicated tracked** module-level active-render-locale override (never colocated with per-keystroke state). Unset on the live site → active locale is `I18n.currentLocale()` (untracked → zero live cost). `setBlockRenderLocale` / `resetBlockRenderLocale` / `activeBlockRenderLocale()`.
- `resolveLocalizedArg(entry, key, themeId)`:
  - **Mode 1:** read `entry.i18n?.["args." + key]` then pick the active locale via **prefix-bucket** matching to align with Discourse content localization (`locale_matchable.rb:9`, `LIKE 'fr%'`): collapse both the active locale and stored keys to their regionless prefix and match within the bucket, so a `fr_FR` translation serves a `fr` / `fr_CA` visitor. Keyed reads only.
  - If the resolved (or base) value is a `{ $t }` reference, resolve **Mode 2**: `i18n("theme_translations." + themeId + "." + key)`, and if that misses, fall back across the loaded `theme_translations` namespace ids (handles a git theme whose translations span the parent plus any stacked components, see §5) before giving up. Reuse the logic behind `helpers/theme-i18n.js`.
  - Returns `undefined` when nothing localized applies (caller falls back to base args → schema default).

**Modify `decorator.js` getter (`:537`)** — try localized, then base, then schema default; `themeId` comes from `contextArgs` (threaded, not read off the entry):
```js
get() {
  const localized = resolveLocalizedArg(entry, key, contextArgs.__themeId);
  const live = localized !== undefined ? localized : entry.args?.[key];
  return live !== undefined ? live : schema[key]?.default;
}
```

**Thread `themeId` into the render context.** Carry the layer wrapper's `themeId` down to `createBlockArgsWithReactiveGetters` as a context arg (alongside `outletName`/`__hierarchy` at `block-outlet.gjs:448-452`); do **not** rely on `entry.themeId`. Re-stamp `themeId` onto `SESSION_DRAFT` entries in `#materializeAllDrafts` / `ensureDraft` (`wireframe.js`) so the editor preview resolves keyed args.

**`block-outlet.gjs` `assignStableKeys` (`:195`)** — wrap `entry.i18n` **and its nested per-path / per-locale maps** in `trackedObject` (the proxy is shallow; nested maps need explicit wrapping for per-locale write reactivity), and **always materialize** `entry.i18n` as at least an empty tracked object so the curry-time spread is never stale.

`RichTextRenderer.runs` already normalizes string and doc-JSON, so a resolved value of either shape renders unchanged.

### 2. Server — validate the optional shapes
`theme_field.rb` `validate_block_layout_entries!` (`:545`): when present, validate `entry["i18n"]` is a Hash of `path => { locale => value }`, and tolerate an arg value of `{ "$t": String }`. Additive; keep `BLOCK_LAYOUT_SCHEMA_VERSION = 1` (unknown keys already pass — `:545-585`).

### 3. Editor — serialize & clone (data-integrity fixes)
- `mutate-layout.js` `serializeEntryForSave` (`:1018`): emit `out.i18n` (deep clone, 3-level) when non-empty.
- `mutate-layout.js` `cloneEntryForDraft` (`:758`) **and** `cloneEntryForPaste` (`:906`): deep-clone `entry.i18n` (3-level path→locale→value), mirroring the explicit `args`/`overrides` clones — without this, paste aliases the source's translations and a re-opened translated layout loses them on draft materialization.

### 4. Editor — locale switcher, inline write path, undo
- **Locale switcher** in editor chrome from `siteSettings.available_locales`; site default = base. On change, call `setBlockRenderLocale` (or reset for base) and track `wireframe.activeLocale`.
- **`wireframe-inplace-text.js`**: `start()` (`:258`) — for a non-base locale read the pre-edit value from `entry.i18n["args."+argName]?.[locale]`; **seed the editor empty**, pass the resolved base value as the placeholder (greyed reference). `applyChange()` (`:401`) — for a non-base locale write `entry.i18n["args."+argName][locale]` (creating nested `trackedObject`s), **delete-on-empty** → falls back to base.
- **Undo / reset must gain a locale axis** (review found this is bigger than one line). The restore path is `writeArgs` (`wireframe.js:2137`), used by undo/redo/`resetAll`/`exit`, and `initialSnapshots` is a flat `argName→value` map with no locale dimension. Extend the snapshot/undo records and `writeArgs` (or a sibling) to address `entry.i18n[path][locale]`; update `#prevValue` capture (`wireframe-inplace-text.js:272`), the `stop` undo-push (`:358`), and the `sameValue` no-op check (`:361`) to compare the active-locale slot. Without this, translate-then-undo corrupts the base copy.
- **`inspector-field.gjs`** `rich-inline` read-only summary reflects the active-locale value.
- **Untranslated cue** (admin chrome SCSS only, no `:has()` on shared/live paths): when a non-default locale is active, fields still showing the base fallback get a subtle `--untranslated` modifier.
- **Whole-layout completeness rollup (v1):** a per-locale view of translated/total counts plus a jump-list of untranslated text fields across the layout, so an admin can verify a layout is fully translated before shipping. Derive it by walking the draft layout's text args against `entry.i18n` per locale.

### 5. Editor — Mode 2: bind to / define theme keys (larger workstream)

> **P2 reconciliation (must resolve before B is scheduled — B lands after A-P4).**
> The original draft reused `Themes::SaveBlockLayout`'s git `-customizations` child
> redirect to land editor-authored translations on a git theme. **A-P2 deleted that
> redirect entirely**, and from P2 on the editor never writes a git theme's live
> fields (publish is blocked by `policy :theme_is_not_git` → 422). So the Mode-2 key
> write path below must follow the **post-P4 git model**: editor-authored strings on
> a git theme live in the per-user draft (the plugin's `wireframe_block_layout_drafts`
> store) and ship via **Export** (write `locales/*.yml` + `block_layouts/*.json` to the
> repo) or **Duplicate** (a new non-git theme the editor *can* write). The
> stack-wide `{ $t }` fallback (§1) stays — it still serves upstream/imported keys that
> span a git parent plus its stacked components.
- **Bind / unbind affordance** (inspector or inline toolbar): "Bind to translation key" replaces a literal with `{ $t: key }`; "Detach to inline text" converts the resolved string back to a literal. A keyed arg renders read-only on the canvas with a "bound to `<key>`" badge.
- **Key definition write path (editor defines keys).** Binding **mints a stable key** (e.g. `block_layouts.<outlet>.<entryId>.<argPath>`; mint `entry.id` on bind if absent) and writes the strings into the theme's translation fields. On Save, the editor sends per-locale `{ key => value }` writes alongside the layout; a server service applies them via `Theme#set_field(target: :translations, name: <locale>, value: <merged yaml>)` — read the existing locale field, deep-merge the key, re-serialize. The **default locale must define the key first** (`theme.rb:741-761,859-863`). Per-locale values go into `locales/<locale>.yml` fields (not `ThemeTranslationOverride`) so they **export to the repo/Crowdin** on theme export.
- **Co-locate layout + translations on the same target theme.** For a non-git (admin-created or duplicated) theme, the write path defines keys directly on that theme. For a git theme there is no live write (and no `-customizations` child — A-P2 removed it): the strings stay in the per-user draft and reach the repo via Export (post-P4 git model).
- **Editor preview of keyed args per locale.** The client only loads the *request* locale's `theme_translations`, so keyed-arg preview can't read other locales from the baked namespace. Because the editor *authors* these strings, it holds them in its own editor state and previews/edits from there; Save persists them. (For purely upstream/imported keys not authored in-session, preview shows the request-locale value only — a documented limitation.)
- **Git-theme resolution.** Upstream/imported keys can live on a git parent and across its stacked components, so `{ $t }` resolution still falls back across all loaded `theme_translations` ids (§1), not a single `themeId` (the client has the whole stack's namespaces, `theme.rb:456`). Editor-authored strings on a git theme are not written live — they live in the per-user draft and ship via Export (post-P4).

## Known limitations (document; confirmed acceptable)
- **Client-only render:** translated block text (both modes) is invisible to crawlers / no-JS visitors — a pre-existing trait of the blocks system (`BlockOutlet extends Component`, `block-outlet.gjs:977`); multilingual SEO of block copy is out of scope.
- **Mode 2 is plain-text only (v1):** a keyed value renders as **escaped literal text** via `MarkedText` — markdown/HTML in `locales/*.yml` displays its raw `**`/`[]()` characters to visitors, not formatting. The bind affordance copy and theme docs must forbid markup in keyed strings until a cooked-render follow-up. Inline-variant text (Mode 1) keeps full rich marks.
- **Mode 2 missing-locale** falls back to the theme default-locale string (no `[missing]` marker, since the shipped `en.yml` resolves — `discourse-i18n/src/index.js:305-328`); a missing translation silently shows the default language. The completeness rollup (§4) is the admin's signal for Mode 1; Mode 2 coverage lives in Crowdin/the repo.

## Critical files
- `frontend/discourse/app/lib/blocks/-internals/locale.js` *(new)* — resolution, active-locale override, prefix-bucket + stack-wide `{$t}` fallback
- `frontend/discourse/app/lib/blocks/-internals/decorator.js` — getter `:537`; consume threaded `__themeId` from `contextArgs`
- `frontend/discourse/app/blocks/block-outlet.gjs` — `assignStableKeys` i18n wrap + always-materialize `:195`; thread `themeId` to context `:448`; re-stamp `themeId` on SESSION_DRAFT `:764`
- `frontend/discourse/app/lib/blocks/-internals/entry-processing.js` — confirm spread `:113` carries tracked `i18n`; cache guard `:88` unchanged
- `app/models/theme_field.rb` — `validate_block_layout_entries!`
- `app/services/themes/save_block_layout.rb` — publish path the translations write co-locates with (post-A-P2: no git redirect; git publish blocked by `policy :theme_is_not_git`)
- `app/models/theme.rb` — `set_field(target: :translations)`, `update_translation`, `transform_ids`/`:translations` baking (`:456,577-583,659,859`)
- `plugins/discourse-wireframe/.../lib/mutate-layout.js` — `serializeEntryForSave:1018`, `cloneEntryForDraft:758`, `cloneEntryForPaste:906`
- `plugins/discourse-wireframe/.../lib/wireframe-inplace-text.js` — `start:258`, `applyChange:401`, `stop:358`, `#prevValue:272`
- `plugins/discourse-wireframe/.../services/wireframe.js` — `activeLocale`, switcher, `writeArgs:2137` + `captureInitialSnapshot:2157` locale axis, `#materializeAllDrafts` themeId re-stamp, completeness rollup
- `plugins/discourse-wireframe/.../components/editor/` — locale switcher, bind/unbind UI, completeness view, `inspector-field.gjs`, untranslated-cue SCSS
- new server endpoint/service for editor-authored theme-translation writes (Mode 2 key definition)

## Verification
1. **Core resolution (qunit)** — `setBlockRenderLocale("fr")` renders the `fr` variant; `fr_CA` resolves a `fr_FR`-stored variant (prefix-bucket); missing locale falls back to base then schema default; a translation added *after* first render re-renders (always-materialized `i18n`, no stale spread).
2. **themeId threading (qunit)** — a `{ $t }` arg on a theme-layer block renders the theme translation for the current locale (proves `themeId` reaches the getter via context, not `entry.themeId`); a draft-layer `{ $t }` arg previews in-editor (SESSION_DRAFT re-stamp).
3. **Data integrity (qunit)** — translate → save round-trips `i18n` (`serializeEntryForSave`); copy/paste a translated block does not alias the source (`cloneEntryForPaste`); re-open a saved translated layout and its translations survive (`cloneEntryForDraft`); translate → undo restores prior state without corrupting base `args`; `resetAll` clears translations.
4. **Server (RSpec)** — `bake_block_layout!` accepts an entry with a valid `i18n` map and a `{ "$t": "key" }` arg, rejects malformed `i18n`; the translations write path defines a key in the default locale + per-locale values via `set_field` and they appear in `theme_translations`. Follow `.skills/discourse-writing-rspec-tests`.
5. **Mode 2 git theme (RSpec/manual)** — editor binds an arg and authors `fr`/`en` strings on a git-imported theme; verify they are held in the per-user draft (not written to the git theme's live fields), that Export emits them into `locales/*.yml`, and that imported `{ $t }` keys resolve via stack-wide fallback at render.
6. **Completeness rollup (qunit)** — counts and the untranslated jump-list reflect per-locale coverage as fields are translated/cleared.
7. **Manual (MCP `discourse-dev`)** — build a layout, switch locale, translate a heading (rich marks survive in Mode 1), Save; load `?lang=fr` and confirm the live site renders the translated copy; switch back to default and confirm base copy. For Mode 2, ship/import a tiny git theme with `block_layouts/*.json` `{ $t }` refs + `locales/en.yml`+`fr.yml` and confirm `?lang=fr` renders French; confirm markup in a keyed string renders as literal text (documents the plain-text limitation).
8. `bin/lint --fix` all changed JS/Glimmer; run `/discourse-code-conventions` on staged JS/Glimmer before any commit.
