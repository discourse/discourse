# Discourse Wireframe — Phased Plan

## Context

Discourse customization today is code-first. Three systems compose the UI:

1. **Plugin Outlets** (`<PluginOutlet @name="…">`) — older, much larger surface area. Connectors are auto-discovered from filesystem paths (`OUTLET_REGEX`), registered via `api.renderInOutlet`. **No runtime enumeration**, **no arg type registry**, connectors are code modules — not data.
2. **Blocks API** (newer, smaller, ~5 core outlets) — `@block(name, options)` decorator with typed `args` schema, container/`childArgs`, conditions (route/user/viewport/setting/outlet-arg with AND/OR/NOT), namespacing, and `api.renderBlocks(outlet, layout)` where `layout` is a JSON-serializable tree. Strict authorization model (blocks render only through `BlockOutlet`).
3. **Themes** — CSS/HBS/JS bundles with theme fields, theme settings, and theme imports. Live preview via `?preview_theme_id=`. Parent/child component model. Install/export/import infrastructure mature.

We want a **drag-and-drop wireframe** as a Discourse plugin (`discourse-wireframe`) that lets admins compose layouts without writing code, with parity for the rest of the industry (Puck, Gutenberg/FSE, Plasmic, Webflow patterns).

**Three core insights that shape the plan:**

- **Blocks is the foundation, and the *only* surface the editor edits.** Layouts are already JSON-serializable trees; arg schemas are typed; conditions are a runtime DSL; the registry is introspectable via `services/blocks.js`. Plugin Outlets are explicitly out of scope — building a bridge from PluginOutlets to Blocks would legitimize the older system and slow migration. The editor's reach grows naturally as more of Discourse (core surfaces, plugins) is rewritten on top of Block Outlets.
- **Themes are the right persistence layer.** Layouts conceptually belong with the rest of a theme's customizations (CSS, JS, settings). Theme infrastructure already provides preview, baking, install, export, Git import, parent/child overrides, MessageBus reload, and a clear ownership story. The editor reads/writes a new `ThemeField` type (`block_layout`), and auto-creates a child theme component on first save when editing a Git-imported theme so upstream syncs don't clobber edits.
- **The wireframe is a *layout* editor, not a CSS editor.** Block args (variant/tone/direction/gap/align) and design tokens from the active theme palette are the user-facing styling surface. Raw CSS stays in the existing Ace-based theme editor.

The biggest gaps to fill are: (a) the layout resolution chain (today only one layout per outlet, registered statically), (b) UI-hint metadata on arg schemas so the inspector renders the right control, (c) discovery metadata on `@block` so the palette can browse, (d) a ThemeField type for layouts, (e) an editor-mode authorization for block previews. The PR #38703 ui-kit consolidation is a parallel asset — not strictly required, but the editor uses ui-kit for its own chrome and benefits from a curated atomic vocabulary that block authors compose against.

## Scope: what the editor edits (and what it doesn't)

**In scope**: any `<BlockOutlet>` registered in core or by a plugin. The 5 core Block Outlets today (`hero-blocks`, `homepage-blocks`, `main-outlet-blocks`, `sidebar-blocks`, `sidebar-discovery`) plus whatever plugins register via `api.registerBlockOutlet`.

**Explicitly out of scope**: Plugin Outlets (`<PluginOutlet>`). These remain code-managed via filesystem-discovered connectors. The path to making more of Discourse editable is to *convert* PluginOutlet positions into Block Outlets in core PRs and plugin upgrades over time. The editor will not bridge or wrap PluginOutlets; we want every new "this should be customizable" decision to express as a Block Outlet.

**Implication for plugin authors**: a plugin that wants its UI to be visually customizable adds `<BlockOutlet @name="my-plugin:thing">` instead of `<PluginOutlet @name="my-plugin:thing">`. Existing PluginOutlets keep working; they're just not editable through this tool.

---

## Editor entry & access

Three coordinated entry points, each with a clear audience. The first ships in Phase 1; the others arrive when persistence and discovery layers do.

**Primary — from the theme admin page** (Phase 3+, when persistence ships).
Each theme's edit page (`/admin/customize/themes/:id`) gets a **"Wireframe"** button alongside the existing Ace-based code editor for CSS/JS. Clicking opens the editor in the context of that theme; a page-picker (homepage / categories / topic / user profile / …) chooses which page mounts in the canvas. Edits land on that theme's `block_layout` ThemeFields, or its auto-created `<theme-name>-customizations` child component if the theme is Git-imported.

This is the canonical entry. Theme authors and power admins manage all customizations (CSS/JS via Ace, layouts via the wireframe) from the same place. It mirrors the existing customization pattern: `admin → customize → themes → show → [edit something]`.

**Secondary — in-context "Edit page" pill** (Phase 1+).
A small floating pill at the bottom-right of any page with at least one mounted `<BlockOutlet>`, visible only to users in `wireframe_allowed_groups` (default: admins). Click → enters editor mode on the current page, editing the active theme.

This is a power-user convenience: an admin spotting something to tweak can fix it in place without navigating to admin. Patterned after the existing dev-tools toolbar (`frontend/discourse/app/static/dev-tools/toolbar.gjs`) — bottom-right, unobtrusive, draggable. Mounted via `api.renderInOutlet` into `above-footer` (or analogous low-traffic outlet) so it doesn't compete with site chrome. Hidden when:
- The current page has no `<BlockOutlet>`s mounted.
- The current user is not in `wireframe_allowed_groups`.
- The site setting `wireframe_enabled` is off.

**Tertiary — admin landing entry** (Phase 8).
`/admin/customize/wireframe` is an index page that lists themes and their editable pages, so admins discover the feature without visiting a theme show page or noticing the pill. Surfaces under `admin → customize → wireframe`, alongside Themes / Color Palettes / Email Styles.

**Permissions**:
- Site setting `wireframe_enabled` (default: off during early phases, on once stable).
- Site setting `wireframe_allowed_groups` (default: admins). The implicit `admins` group covers staff; other groups are opt-in.
- Server-side: any save requires both the user permission AND `Guardian#can_edit?(theme)` for the target theme (already exists for theme editing).

**Activation flow** (any entry point):
1. User clicks entry → editor service flips `isActive = true` and stores the target theme + page in a session.
2. Body class `body.wireframe-active` toggles editor CSS.
3. `debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, …)` patches block rendering with selection chrome.
4. The 3-pane shell (toolbar, left palette/outline, right inspector) mounts via `api.renderInOutlet`-style hooks.
5. Original page DOM remains in the canvas region.

**Exit flow**:
- Save → persists to ThemeField, exits, returns to viewing the page.
- Discard with unsaved changes → confirmation modal, then exits.
- Browser back / route change → confirmation if dirty.
- Permission revoked mid-session → toast + redirect.

---

## Recommended approach — at a glance

- **Foundation**: Blocks system. Plugin Outlets bridged later via an `outlet-renderer` block.
- **Editor surface**: in-place, NOT iframe. The live page wraps in a 3-pane chrome (toolbar / palette+outline / canvas / inspector). Block-system reactivity carries the canvas; no postMessage, no parallel app boot.
- **Persistence**: new `block_layout` ThemeField type. Editor reads/writes ThemeFields on the active theme. First save against a Git-imported theme auto-creates a child theme component (`<theme-name>-customizations`) so upstream syncs are preserved.
- **Resolution chain**: code defaults → ancestor theme components → child overrides → live in-editor draft. Already mostly implied by the theme stack — the new piece is making `BlockOutlet#validatedLayout` resolve through the same stack.
- **Authorization**: a scoped, time-limited token via `api.createBlockPreviewToken({ ttl, scope })` + a new `<BlockPreviewHost>` core component. Allows isolated previews in palette/inspector without weakening the AUTH_TOKEN model.
- **DnD**: Pragmatic dnd (Atlassian, 16KB, framework-agnostic). Existing `modifiers/draggable.js` is too low-level; HTML5 native DnD has nested-target issues.
- **Inspector**: FormKit-driven. Schema → form generated from each block's `args` + new optional `ui:` hint. 37 control types already exist in `frontend/discourse/app/form-kit`.
- **Editor chrome**: piggy-backs on the existing dev-tools patching pattern (`debugHooks.setCallback`, `_setOutletDebugCallback`). Same hook the block-debug overlay uses.
- **Persona + viewport simulators** in the toolbar — drive condition re-evaluation so admins see who-sees-what without leaving the editor.
- **Styling**: structured, never raw. Block args expose presentation knobs; the inspector picks colors from the theme palette, never arbitrary; per-instance overrides (Phase 8+) are a bounded "Style" tab over CSS variables, not freeform CSS.

---

## ui-kit (PR #38703) — role in the plan

PR #38703 moves 76 atomic components, 25 helpers, 10 modifiers under `app/ui-kit/` with a `d-` prefix. It is **not** the block library — atoms are too low-level for typical drag-drop. But it matters at three layers:

1. **Editor UI itself uses ui-kit.** Every panel, button, form control. A stable, named target makes the editor robust to internal refactors.
2. **Block authors compose blocks from ui-kit atoms.** The kit is the vocabulary for blocks. Block library docs become "use `<DCard>` for a card surface, `<DButton>` for actions" instead of grep-the-codebase.
3. **A future "primitives" tier in the palette.** Some ui-kit atoms can be auto-block-ified through a generic wrapper so power users have access to atoms when needed — but this is opt-in and Phase 8+ at earliest. The default palette ships only composed blocks.

ui-kit also unlocks **versioning**: a curated kit can be semver'd; community blocks declare which ui-kit version they target. This pays off as the third-party block ecosystem grows.

The wireframe doesn't *block on* the ui-kit PR landing — but every phase benefits proportionally as more components migrate over. Practical recommendation: prioritize the ui-kit consolidation in parallel with Phase 1–2; by Phase 6 (palette + starter blocks) it should be the default substrate for newly-authored blocks.

---

## Styling strategy — how CSS fits

The editor is a layout editor, not a CSS editor. Three layers of styling, in order of editor-exposure:

1. **Block args (presentation knobs)** — primary styling surface. Block authors expose typed args like `variant: "compact" | "expanded"`, `tone: "neutral" | "warning" | "danger"`, `direction: "row" | "col"`, `gap: 8 | 16 | 24`, `align: "start" | "center" | "end"`. The block's CSS handles them via class modifiers. The editor's inspector exposes them as controls (select / radio / number). This is what most editing actually does.

2. **Design tokens** — the theme palette (already wired via the existing color palette editor) provides named tokens. The inspector's color/font/spacing pickers select from those tokens, not arbitrary values. Picking a "primary accent" surface-binds the block to whatever the theme defines as primary, so layouts re-skin automatically when the theme changes.

3. **Per-instance overrides (Phase 8+)** — a bounded "Style" tab in the inspector with structured controls for padding, margin, color, border, typography. Generates scoped `block--id-<id>` CSS rules or inline styles, stored on the layout entry. Never raw CSS — the control set is fixed.

What the editor explicitly does **not** do:

- Raw CSS editing — that's the existing Ace-based theme editor's job.
- Selector debugging or specificity workarounds — wireframe users shouldn't see CSS selectors.
- Theme-wide CSS edits — those live in theme files. The editor edits *layout*, themes own *style*.

Layout-level styling (grid/flex/columns) lives in **container blocks**: `BlockGroup` exposes `direction`, `gap`, `align` as args; new container blocks for grids and columns ship in Phase 6's starter library. Users get powerful layout primitives without writing flexbox.

---

## Foundational core changes (the API gaps)

These are the changes the plugin cannot make on its own. Each is additive and backward-compatible. The summary table below is followed by per-change deep dives covering rationale, concrete API, implementation sketch, and trade-offs.

| # | Change | Difficulty |
|---|---|---|
| 1 | **UI hints in `ArgSchema`** — `ui: { control, group, label, placeholder, helpText, hidden, conditional }` | S |
| 2 | **Discovery metadata on `@block`** — `displayName`, `icon`, `category`, `previewArgs`, `thumbnail` | S |
| 3 | **Layout resolution chain + `api.replaceLayout`** — priority-stack of layout sources per outlet | **L** |
| 4 | **Editor preview-mode authorization** — scoped token + `<BlockPreviewHost>` for isolated previews | M (security review) |
| 5 | **Block Outlet enumeration with metadata** — outlet registry carries description/category/etc. | S |
| 6 | **`block_layout` ThemeField type** — JSON layouts as a first-class theme asset | M |
| 7 | **Auto-child-theme-component policy** — protect Git-imported themes from edit clobbering | S |
| 8 | **MessageBus reactive layout reload** — publish/subscribe layout updates across tabs | S |
| 9 | **Container slots metadata** — multi-slot containers (additive, optional) | S/M |

No `outlet-renderer` block, no PluginOutlet bridge — see the Scope section.

---

### #1 — UI hints in `ArgSchema`

**Problem**: today's `ArgSchema` (`frontend/discourse/app/lib/blocks/-internals/decorator.js:156–170`) describes *types* (`string` / `number` / `boolean` / `array` / `any` plus `min`/`max`/`enum`/`pattern`), but says nothing about *how to edit* a value. A `string` could be a one-liner, a long description, a hex color, an icon name, a category slug, an upload URL, or a chunk of HTML — the inspector has no way to know which control to render.

**Proposal**: add an optional `ui` field to each arg in the schema. Consumed by the editor; ignored at validation/runtime.

```js
@block("hero-banner", {
  args: {
    title:       { type: "string", required: true,
                   ui: { control: "text", placeholder: "Welcome" } },
    description: { type: "string", maxLength: 800,
                   ui: { control: "textarea", group: "Content" } },
    accentColor: { type: "string",
                   ui: { control: "color", group: "Appearance" } },
    icon:        { type: "string",
                   ui: { control: "icon" } },
    image:       { type: "string",
                   ui: { control: "image-upload" } },
    ctaUrl:      { type: "string",
                   ui: { control: "url",
                         conditional: { arg: "ctaLabel", notEmpty: true } } },
  }
})
```

**`ui` shape** (all optional):
- `control: "text" | "textarea" | "number" | "toggle" | "select" | "radio-group" | "color" | "icon" | "emoji" | "image-upload" | "url" | "rich-text" | "code" | "category-select" | "tag-select" | "user-select" | "group-select"` — overrides the default mapping.
- `label: string` — overrides the field label.
- `placeholder: string` — input placeholder.
- `helpText: string` — small description below the field.
- `group: string` — section header in the inspector ("Content", "Appearance", "Behavior"). Args without a group fall under "General".
- `hidden: boolean` — hides from inspector but keeps in schema (computed args).
- `conditional: { arg: string, equals?: any, notEmpty?: boolean }` — show this field only when another arg has a particular value.

**Implementation sketch**:
- `frontend/discourse/app/lib/blocks/-internals/decorator.js` — extend the JSDoc typedef. No runtime change.
- `frontend/discourse/app/lib/blocks/-internals/validation/block-args.js` — `validateArgsSchema()` accepts the new `ui` key, validates the shape, but ignores its values for runtime correctness.
- The editor reads `metadata.args[argName].ui` at inspector-render time.

**Trade-offs / alternatives considered**:
- **Why on the schema, not in editor configuration?** Because the block author knows best how their args should be edited. Putting it in the schema means a third-party block ships with a sensible inspector for free.
- **Why not a separate `editorSchema`?** Two schemas drift. One schema with optional UI hints is one source of truth.
- **JSON-Schema or Zod instead?** The existing `ArgSchema` is bespoke and well-integrated. Migrating to JSON-Schema is a much bigger change with no clear win. Stay bespoke; document it well.

---

### #2 — Discovery metadata on `@block`

**Problem**: `BlockMetadataEntry` (decorator.js:60) carries `blockName`, `shortName`, `description`, `isContainer`, etc. — enough to *render* a block, but not enough to *browse* one. The palette has nothing to display besides the block name.

**Proposal**: extend `@block(name, options)` with optional discovery fields.

```js
@block("hero-banner", {
  displayName: "Hero Banner",            // i18n-able human label
  icon: "rocket",                         // FontAwesome name (or :iconName)
  category: "Layout",                     // palette grouping: "Layout" | "Content" | "Navigation" | "Data" | custom
  previewArgs: { title: "Welcome", subtitle: "Join the conversation" },
  thumbnail: "/plugins/discourse-wireframe/images/hero-banner.svg",
  // existing options unchanged
})
```

All optional. Defaults:
- `displayName` falls back to a Title-Cased form of `shortName`.
- `icon` falls back to a generic block glyph.
- `category` falls back to `"Misc"`.
- `previewArgs` falls back to the schema's `default` values for each arg.
- `thumbnail` falls back to a category-derived placeholder SVG.

**Implementation sketch**:
- `decorator.js` — accept the new keys in the options object, store on `BlockMetadataEntry`.
- `services/blocks.js#listBlocksWithMetadata()` — already returns the metadata; new fields surface for free.
- New helper `getBlockDisplayMetadata(component)` that fills in defaults so palette code doesn't have to.

**Trade-offs / alternatives considered**:
- **Why not a separate `palette()` decorator?** Decorator stacking is brittle in glimmer; one decorator with grouped options is simpler.
- **Should `category` be an enum?** No — a string allows plugins/themes to introduce new categories. The palette groups dynamically.
- **Should `thumbnail` be required?** No. Most blocks render fine with an icon. Authors can opt into a real thumbnail when they want extra polish.

---

### #3 — Layout resolution chain + `api.replaceLayout`

This is the single biggest core change and the one most worth scrutinizing.

**Problem**: `_renderBlocks` (block-outlet.gjs:335) is one-shot per outlet. The internal `outletLayouts: Map<string, {validatedLayout}>` allows exactly one layout per outlet name; a second `api.renderBlocks(...)` for the same outlet throws. This is fine when only code is registering layouts. It breaks down the moment we have:

- A code-registered default layout (from a plugin or core).
- A theme-shipped layout (from a theme component's `block_layout` ThemeField).
- A theme-author override of an inherited theme layout.
- The editor's in-memory draft that overrides everything for the current admin session.

We need a way for these layers to coexist with deterministic precedence, with the ability to dynamically replace any layer at runtime (load on theme stack hydration; update on save; swap on persona change).

**Proposal**: a fixed three-layer **enum** (no plugin-supplied numbers). Layers are ordered intrinsically; within a layer, ordering follows existing conventions.

```js
// Fixed enum, ordered from highest precedence to lowest:
const LAYOUT_LAYERS = ["session-draft", "theme", "code-default"];
```

**Layers**:
- `code-default` — set by `api.renderBlocks(outletName, layout)` (the existing API). One per source-of-registration. Lowest precedence.
- `theme` — set by the theme-load initializer reading `block_layout` ThemeFields from the active theme stack. **Multiple themes can contribute layouts**; ordering within this layer follows the existing theme-stack precedence (the same rule that already governs how multiple theme components' CSS/JS combine — last in the stack wins). The plan does not invent its own ordering here.
- `session-draft` — set by the editor while a user is editing. Singleton per session. Highest precedence.

A user-supplied integer is *not* part of the API. The layer name maps to a deterministic precedence; within `theme`, the existing theme stack does the rest.

**Internal data shape**:

```js
// outletLayouts holds, per outlet, one entry per layer (theme layer holds an array indexed by stack position):
{
  "homepage-blocks": {
    "session-draft": { layout, validated },           // optional
    "theme": [                                         // ordered by theme stack
      { themeId: 5, themeFieldId: 12, layout, validated },
      { themeId: 7, themeFieldId: 15, layout, validated }
    ],
    "code-default": { source: "plugin:my-plugin", layout, validated }
  }
}
```

**Public API surface**:

```js
// Existing — unchanged behaviour, becomes a thin wrapper:
api.renderBlocks(outletName, layout)
// Internally registers in the "code-default" layer, keyed by call-site source.

// New — for the editor and the theme-load initializer:
api.setLayoutLayer(outletName, layer, layout, options = {})
// layer: "session-draft" | "theme"
// options.themeId: number (required when layer === "theme")

api.clearLayoutLayer(outletName, layer, options = {})
// Clears the entry. For "theme", options.themeId targets a specific theme.
```

That's the entire surface. Three layers, predictable resolution, no priority arithmetic.

**Resolution algorithm**:

```js
function resolveLayout(outletName) {
  const layers = outletLayouts.get(outletName) ?? {};
  // Highest precedence first:
  if (layers["session-draft"]) return layers["session-draft"];
  if (layers["theme"]?.length) return layers["theme"].at(-1); // last in theme stack wins
  if (layers["code-default"]) return layers["code-default"];
  return null;
}
```

On *validation* failure, fall through to the next layer. The fall-through is also fixed by the enum.

**Reactivity**: store the per-outlet layer object as a `trackedMap` so editor mutations and MessageBus updates trigger re-resolution.

**Freeze semantics** (unchanged):
- The block *registry* (which classes exist) remains frozen post-`freeze-block-registry`.
- The *layout* layers become mutable post-freeze. Layouts are data referencing already-registered blocks; freezing them is unnecessary.

**Loading flow**:
1. Pre-initializers register blocks/conditions/outlets.
2. `freeze-block-registry` runs.
3. Initializers call `api.renderBlocks(...)` — entries land in the `code-default` layer.
4. New `load-theme-block-layouts` initializer reads each theme's `block_layout` ThemeFields and calls `api.setLayoutLayer(outlet, "theme", layout, { themeId })`. Done in theme-stack order so the array is naturally sorted.
5. Editor activation: `api.setLayoutLayer(outlet, "session-draft", draftLayout)`. Save publishes the corresponding `theme` entry; on save+exit, the draft is cleared.

**Implementation sketch**:
- `frontend/discourse/app/blocks/block-outlet.gjs` — replace single-entry `outletLayouts` with the per-layer shape; add `_setLayoutLayer`, `_clearLayoutLayer`; rewrite `_renderBlocks` to delegate to `_setLayoutLayer(outlet, "code-default", layout)`; rewrite `BlockOutlet#validatedLayout` to use `resolveValidatedLayout`.
- `frontend/discourse/app/lib/plugin-api.gjs` — add `api.setLayoutLayer`, `api.clearLayoutLayer` near line 3420.
- Tests: per-layer resolution, fall-through on validation failure, theme stack ordering, draft activation/clear cycle.

**Trade-offs / alternatives considered**:
- **Integer priorities (the previous draft)** were rejected: arbitrary numbers invite plugin-vs-plugin contention without clear semantics. Enum forces design intent.
- **Could we skip the enum entirely and just have "default" + "override" + "draft"?** The existing theme-stack precedence is meaningful and well-understood; surfacing the `theme` layer explicitly avoids confusion when two themes both ship a layout for the same outlet.
- **Where does a future "site-setting layout" go?** It would be a new layer in the enum, slotted between `code-default` and `theme` — a deliberate core PR. The closed enum is the point.
- **Lock semantics** (from earlier draft) — not needed. Layer ordering is enough; the `session-draft` layer wins by definition.

**Risks**:
- The block-outlet rendering path is hot. Per-outlet resolution is O(1) here (three lookups + theme array tail). Profile to confirm.
- Debugging which layer is winning. Add a dev-tools panel that shows the active layer per outlet.

---

### #4 — Editor preview-mode authorization

**Problem**: `BlockComponentManager` (decorator.js:120) enforces that block components are *only* instantiated either as the root (`BlockOutlet`) or as a child whose parent passed the `AUTH_TOKEN` symbol via `__block$`. This is a security property: it prevents arbitrary code from instantiating blocks outside the outlet system.

The editor needs to render isolated block previews:
- In the palette (a tiny preview thumbnail for each available block).
- In the inspector (a "live preview" showing the block with the user's current arg edits before they apply).
- In a future "block preview" admin page for documentation.

These previews don't live inside a `BlockOutlet`. Today they would throw.

**Proposal**: a *scoped, time-limited, owner-bound* token that opens a third authorization path. Tokens are minted by core, never globally exposed.

```js
// New core API
api.createBlockPreviewToken({ ttl: 60_000, scope: "palette" | "inspector" | "preview-page" })
// Returns: a Symbol stored in a closure, with metadata: { mintedAt, ttl, scope, ownerId }

// New core component
import BlockPreviewHost from "discourse/blocks/block-preview-host";

<BlockPreviewHost
  @block={{this.HeroBanner}}
  @args={{this.previewArgs}}
  @token={{this.previewToken}}
/>
```

`<BlockPreviewHost>` is the *only* component allowed to instantiate a block via a token. It does:
1. Verifies the token is unexpired and matches the current owner.
2. Curries the block component with args + the token marker.
3. Renders the curried component inside its own DOM.

`BlockComponentManager` is extended with a third path:
```js
const isPreviewHost = klass === BlockPreviewHost;  // or a less-direct check
const isAuthorizedPreviewChild = named?.get("__previewToken$")?.compute() === providedToken;
```

**Threat model**:
- A malicious plugin could call `api.createBlockPreviewToken(...)` and use it to render arbitrary blocks. **Acceptable**: a malicious plugin can already do far worse. The token only loosens the *display* restriction; the block's own logic still runs in the same security context.
- Token leak through serialization or logs. **Mitigation**: tokens are `Symbol`s — non-enumerable, non-serializable, stable equality only via reference. They can't be JSON-stringified or printed meaningfully.
- Token reuse after expiry. **Mitigation**: TTL is enforced inside `BlockComponentManager` by checking `mintedAt + ttl >= now()`.
- Owner mismatch (a token minted by plugin A used by plugin B). **Mitigation**: the token closure binds to the owner that created it; the manager checks owner match.

**Implementation sketch**:
- New file `frontend/discourse/app/blocks/block-preview-host.gjs` — the host component.
- `frontend/discourse/app/lib/blocks/-internals/decorator.js` — extend `BlockComponentManager` with the third authorization path.
- `frontend/discourse/app/lib/plugin-api.gjs` — add `api.createBlockPreviewToken`.
- Internal token registry (`Map<Symbol, { mintedAt, ttl, scope, ownerId }>`) lives in the decorator module's closure.

**Trade-offs / alternatives considered**:
- **Why not just relax `BlockComponentManager` to allow rendering anywhere?** Loses the "blocks compose correctly" property. A block whose template assumes outlet-args-as-getters would break in unexpected places.
- **Why not a per-block "is-previewable" flag?** Forces every block author to opt in. The token approach is opt-out for the user (they get previews for any block) and opt-out at the *manager* level (only the host component is privileged).
- **Why a Symbol token instead of a JWT?** Simpler. The token never leaves JS-land; it's not transmitted over network. A Symbol is unforgeable in-process.
- **Could we just instantiate the block class manually without the manager?** Bypassing the manager skips authorization entirely, which defeats the point. Going through the manager keeps the security boundary explicit.

**Open question for the user**: do we want previews to be able to call services and access the current user, or should they render in a *more* isolated context (e.g., as if anonymous)? Recommend full-context previews for now; the editor user is an admin and inspecting their own page state is the natural mental model.

---

### #5 — Block Outlet enumeration with metadata

**Problem**: today, `BLOCK_OUTLETS` (`frontend/discourse/app/lib/registry/block-outlets.js`) is `["hero-blocks", "homepage-blocks", "main-outlet-blocks", "sidebar-blocks", "sidebar-discovery"]` — just strings. Plugins can register more via `api.registerBlockOutlet(name, { description })`. The editor needs more *catalogue*-shaped data: a label, a category, a representative screenshot.

**Constraint we explicitly avoid**: declaring the outlet's *args* in the registry. Args declarations would drift from `<BlockOutlet @outletArgs={{...}} />` template usages. Instead, the editor reads `outletArgs` at runtime from the currently-mounted `<BlockOutlet>` instance (the same Proxy that already powers deprecation tracking, `lib/outlet-args.js`).

**Constraint we explicitly avoid**: an outlet-side `allowedBlocks` whitelist. Blocks already declare `allowedOutlets`/`deniedOutlets` from their own side. A two-way restriction is redundant and creates a maintenance burden — a new block author would need to coordinate with every outlet that should accept it. Keep it one-way: blocks declare where they belong.

**Proposal**: outlet registry carries lightweight, catalogue-only metadata. No schema, no whitelist.

```js
// Registry shape (fields all optional except `name`)
{
  name: "homepage-blocks",
  description: "Main content area on the site homepage.",
  category: "page" | "navigation" | "content" | "embed" | string,   // for palette grouping
  defaultLocation: "/",                                              // route or page identifier where this outlet typically appears
  screenshot?: string,                                               // hand-authored thumbnail for the catalogue
  hidden?: boolean,                                                  // outlet exists but should not appear in the editor catalog
}
```

That's it. Args contracts are discovered at runtime; block↔outlet compatibility is governed by `allowedOutlets`/`deniedOutlets` on the block.

**Migration**: `BLOCK_OUTLETS` constant becomes a registration call site; each core outlet registers with the new shape. `api.registerBlockOutlet(name, metadata)` accepts the same.

**Surface**: `services/blocks.js#listOutlets({ withMetadata: true })` returns the metadata. Default form remains the current `string[]` for backwards compatibility.

**Implementation sketch**:
- `frontend/discourse/app/lib/blocks/-internals/registry/outlet.js` — change registry from `Set<string>` to `Map<string, OutletMetadata>`.
- Core outlets register their metadata in the same file.
- `services/blocks.js#listOutlets` — accept options.

**Trade-offs / alternatives considered**:
- **Why not derive `outletArgs` schema from a usage-sourced declaration?** Could co-locate (`<BlockOutlet @name=... @outletArgsSchema={{...}} />`) but that adds noise at every call site. Runtime introspection is enough for editor needs (the user is only editing one currently-mounted instance at a time).
- **Should `screenshot` be auto-generated?** Would require headless rendering. Out of scope. Hand-authored thumbnails or category placeholders.

---

### #6 — `block_layout` ThemeField type

**Problem**: layouts need to live alongside CSS, JS, and translations as a first-class theme asset, leveraging the theme system's preview, baking, install, export, and Git import. Today, ThemeField types are: `extra_scss`, `var_theme_fields`, `locale_fields`, `yaml_theme_fields`, `builder_theme_fields`, `upload_fields`. There's no field for "structured JSON layout."

**Proposal — DB shape**:
- New ThemeField type `block_layout` (next available `type_id`). One field per outlet.
- `theme_fields.value` (existing `text` column) stores a JSON string.
- `theme_fields.name` (existing column) holds the outlet name (`"homepage-blocks"`, `"sidebar-discovery"`, `"chat:thread-blocks"`).
- `theme_fields.target_id` enforced to `common (0)` — viewport conditions handle desktop/mobile differentiation.

**Proposal — Git theme representation**:

Theme Git imports today use convention-based file paths to populate ThemeFields. Layouts get a new conventional directory:

```
theme/
  about.json
  settings.yml
  common/
    head_tag.html
    common.scss
  javascripts/
    discourse/
      api-initializers/
        my-init.js
  locales/
    en.yml
  block_layouts/                       <-- new
    homepage-blocks.json
    sidebar-blocks.json
    sidebar-discovery.json
    chat__thread-blocks.json           <-- "::" namespaces are encoded as "__" on disk to be filename-safe
```

Each file is a JSON document:

```json
{
  "schema_version": 1,
  "layout": [
    { "block": "hero-banner", "args": { "title": "Welcome" } },
    {
      "block": "block-group",
      "args": { "direction": "row", "gap": 16 },
      "children": [
        { "block": "feature-card", "args": { "title": "First" } },
        { "block": "feature-card", "args": { "title": "Second" } }
      ]
    }
  ]
}
```

The theme importer (`Theme.import_theme_from_repo` and friends) recognizes the `block_layouts/` directory and creates one `block_layout` ThemeField per file. The exporter does the reverse — when packaging a theme into a `.tar.gz` or pushing to a Git remote, layouts in the DB serialize back into files in this directory.

**Schema versioning**: every layout file declares `schema_version`. The plugin and core ship a migrator chain (each version → next) so old themes keep working as the layout shape evolves. Initial release is `schema_version: 1`. Migrators live in `app/services/themes/block_layout_schema_migrator.rb`.

**Validation on save** (server-side):
1. Parse JSON; reject malformed.
2. Run the existing JS validator (`frontend/discourse/app/lib/blocks/-internals/validation/layout.js`) via MiniRacer. The validator is the source of truth; porting to Ruby risks drift.
3. Reject on hard failures (depth > `MAX_LAYOUT_DEPTH`, malformed entries, invalid condition shapes, `allowedOutlets`/`deniedOutlets` violations).
4. Soft-warn on unresolved block refs (e.g., a referenced plugin block isn't installed on this site) — record warnings; don't reject. Editor surfaces them.

**Baking**: theme baking already runs per-field; the `block_layout` type's "baked" output is just the parsed JSON cached on the field. No JS/CSS compilation.

**Site serializer**: extend with a per-theme `block_layouts` array — `[{ outlet: "homepage-blocks", layout: {...}, theme_id, schema_version }]` — loaded on boot by a new client initializer that calls `api.setLayoutLayer(outlet, "theme", layout, { themeId })`.

**Reset semantics**: deleting the field falls through to the next theme in the stack or to `code-default` via the resolution chain.

**Implementation sketch** (server):
- `app/models/theme_field.rb` — register the new type.
- `app/models/theme.rb` — collection accessor `theme.block_layouts`.
- Theme importer (`lib/theme_importer.rb` or analog) — recognize `block_layouts/*.json`.
- Theme exporter — serialize fields back to files.
- `app/serializers/site_serializer.rb` — push layouts to client.
- `app/services/themes/save_block_layout.rb` — uses `Service::Base`. Validates via MiniRacer.

**Implementation sketch** (client):
- `frontend/discourse/app/initializers/load-theme-block-layouts.js` — runs after `freeze-block-registry`, reads `Site.user_themes[i].block_layouts`, calls `api.setLayoutLayer` per outlet.

**Trade-offs / alternatives considered**:
- **One file with all outlets vs. one file per outlet.** Per-outlet wins: editors typically touch one outlet at a time; merging changes across themes is cleaner; deleting/resetting a single outlet doesn't risk others.
- **Why JSON files at the root, not under `common/`?** `common/` is conceptually for per-target (common/desktop/mobile) assets. Layouts are target-agnostic (viewport conditions handle that). A top-level `block_layouts/` directory parallels `locales/`.
- **JSON-Schema for the file?** Could publish one for editor tooling. Not in v1; the JS validator is canonical.
- **MiniRacer for validation vs. Ruby port.** MiniRacer is the right call — the JS validator is the source of truth. Cache the validator instance per process.
- **Filename encoding for namespaced outlets (e.g. `chat:thread-blocks`).** Use `__` (double underscore) in filenames; map back to `:` on import. Documented in the importer.

---

### #7 — Auto-child-theme-component policy

**Problem**: when a theme is Git-imported (`themes.remote_theme_id IS NOT NULL`), it has an upstream source. The next remote sync overwrites the theme's fields with what's at the remote. If an admin edits a Git-imported theme's layouts via the editor, those edits get clobbered.

**Proposal**: when the editor saves to a Git-imported theme, *redirect* the save to a child theme component, auto-creating it if necessary.

**Naming convention**: `<theme-name>-customizations`. Created with `component: true`, parent set to the original theme. Auto-installed on the original theme as a component.

**Behavior**:
1. Editor calls `Themes::SaveBlockLayout` with `theme_id: 42, outlet: "homepage-blocks", layout: {...}`.
2. Service inspects theme 42:
   - `remote_theme_id IS NULL` → write directly to theme 42's ThemeField.
   - `remote_theme_id IS NOT NULL` → find or create `<theme-42-name>-customizations`, write the field there. Inform the client via response that the save was redirected.
3. Editor toolbar shows a small notice on first save: "Saved to *<theme-name>-customizations* — your edits won't be overwritten by upstream theme updates." Dismissable. Stored in user preference so future saves are silent.

**Edge cases**:
- The customizations component already exists but isn't a child of the parent theme → re-link.
- The user explicitly wants to write to the parent (e.g., theme author working on the upstream) → an "advanced" toggle in the toolbar: "Write to upstream theme directly." Hidden by default. Confirmed via modal.
- The customizations component has its own remote (someone Git-imported it, weird but possible) → fall back to creating a new one with a numeric suffix (`<theme-name>-customizations-2`) and warn.

**Implementation sketch**:
- New service in core: `app/services/themes/save_block_layout.rb` (uses `Service::Base` per `discourse-service-authoring`).
  - Contract: `theme_id, outlet_name, layout_json, force_parent? (default false)`.
  - Steps: lookup theme → policy `can_edit_theme?` → branch on `remote_theme_id` → upsert ThemeField → bake → return `{ theme_id, redirected_to_id?, theme_field_id, child_created? }`.
- Plugin-side persistence service calls this and surfaces the redirection in the toolbar.

**Trade-offs / alternatives considered**:
- **Always redirect (even for non-Git themes)?** Overkill for most cases. Direct edit is simpler when there's no upstream. Stick with conditional redirect.
- **Naming: should it be `<theme-name>-overrides`, `-customizations`, `-edits`?** Use whichever convention the Discourse theme ecosystem already prefers. Default proposal: `-customizations` (consistent with theme-component naming patterns).
- **Should the user be able to opt out of redirection per save?** Yes, via the "advanced" toggle. Default behavior is safe; advanced behavior is reachable.
- **What if the user edits the customizations component directly via the editor?** That's fine — it's not Git-imported, so direct edit works. The editor doesn't need special-case handling.

---

### #8 — MessageBus reactive layout reload

**Problem**: when one tab publishes a layout edit, other tabs (or other users) should see the update without a manual reload.

**Proposal**: leverage the existing theme-change MessageBus channels. Theme changes already trigger client-side updates for CSS / JS / translations.

**Verify before implementing**: there's already a `MessageBus.publish "/file-change", ["development-mode-theme-changed"]` hook in `theme.rb`. The frontend has theme update handling. Likely we can hook the existing flow:

1. ThemeField update for a `block_layout` type → existing theme save path triggers MessageBus publish.
2. Client receives → existing handler calls a hook for layout updates.
3. New hook calls `api.replaceLayout(...)` for each updated outlet.

If the existing theme reload mechanism *forces a page refresh* (which it might for safety), we have two options:
- **Option A**: keep page-refresh behavior. Layouts reload as part of the bigger refresh. Simple, slight UX cost.
- **Option B**: skip the page refresh for layout-only updates. Faster, but introduces a new "partial update" code path. More complex.

**Recommendation**: start with **Option A** in Phase 3 (correctness over speed; rare event in practice). Move to Option B as a polish item only if user feedback demands it.

**Implementation sketch**:
- `app/models/theme.rb` — when a `block_layout` field changes, ensure a MessageBus publish goes out (likely already does via the theme save hook).
- Client-side initializer subscribes to `/file-change` (or the theme-specific channel) and looks for layout updates in the payload.
- Calls `api.replaceLayout(outletName, layout, { priority, source: { type: "theme", themeId } })`.

**Trade-offs / alternatives considered**:
- **Dedicated `/block-layouts/:outlet` channel vs reusing theme channels?** Theme channels already exist and carry the right context. Reuse.
- **Push the actual layout JSON over MessageBus, or just an "invalidate" signal?** Signal is smaller; the client refetches. Push is faster but bloats the bus. Signal is safer.

---

### #9 — Container slots metadata

**Problem**: today, container blocks accept children as a single ordered list (`@children`). Many real layouts want multiple distinct slots: a two-column container has `primary` and `sidebar`; a card has `header`, `body`, `footer`.

**Proposal**: optional `slots` metadata on `@block(...)`, with a per-child-entry `slot` field. Slot definitions describe shape (label, cardinality), **not** which blocks they accept — block↔outlet/slot compatibility stays one-way (declared on the block via `allowedOutlets`/`deniedOutlets`).

```js
@block("two-column", {
  container: true,
  slots: {
    primary: { label: "Primary content", min: 1, max: 5 },
    sidebar: { label: "Sidebar", max: 3 }
  },
  childArgs: { /* args passed to children */ }
})
```

```js
// Layout entry with slots
{
  block: "two-column",
  children: [
    { block: "hero-banner",  args: {...},  slot: "primary" },
    { block: "feature-card", args: {...},  slot: "primary" },
    { block: "tag-cloud",    args: {...},  slot: "sidebar" }
  ]
}
```

**Defaults**:
- A container with no `slots` field behaves exactly as today (single ordered list, no `slot` field on children).
- A container with `slots` but a child without a `slot` field falls into a default slot (first defined slot, or warn).
- The `@children` arg the container receives becomes a slot-keyed object: `{ primary: ChildBlockResult[], sidebar: ChildBlockResult[] }`. Containers iterate per slot in their template:

```hbs
<div class="primary"> {{#each @children.primary as |c|}} <c.Component /> {{/each}} </div>
<div class="sidebar"> {{#each @children.sidebar as |c|}} <c.Component /> {{/each}} </div>
```

**Editor impact** (Phase 7+):
- Drop zones rendered per slot.
- Inspector for the container shows slot definitions.
- Block→slot compatibility is determined entirely by the block's own `allowedOutlets`/`deniedOutlets` (treated as also matching slot names of the form `<outlet>:<slot>`, e.g. `homepage-blocks:sidebar`).

**Implementation sketch**:
- `decorator.js` — accept `slots` option, validate it (slot names match `[a-z][a-z0-9-]*`, each entry has optional `label`/`min`/`max`).
- `frontend/discourse/app/lib/blocks/-internals/components/block-outlet-root-container.gjs` and `entry-processing.js` — when assembling `@children`, group by `slot` if the container has slots metadata.
- Validation: `min`/`max` enforced at layout validation time.

**Trade-offs / alternatives considered**:
- **Glimmer named blocks (`<:header>`, `<:body>`)?** Only work for in-template usage. Block layouts come from JSON, not templates. Slots-via-keys is the right shape.
- **Should slots be position-aware (slot order in JSON matters)?** Yes — within a slot, order is preserved. Across slots, the container template controls placement. Same as today's flat list.
- **What about dynamic slots?** Out of scope. If a future block needs them, it can structure args differently.
- **Why no `allowedBlocks` per slot?** Two-way restriction creates maintenance churn (every new block author needs to coordinate with every container that should accept it). The block's own `allowedOutlets`/`deniedOutlets` is the single declaration. Slot-aware patterns (e.g., a "header block" being limited to header slots) are encoded as outlet-name patterns the block opts into, not as container-side whitelists.
- **Defer to Phase 8?** Ship the metadata fields in Phase 6 (so block authors can declare slots) and switch the rendering path on once at least one slotted container ships in the starter library.

---

## Phased rollout

### Phase 1 — "Visualize what's already there" (no core changes)
**Goal**: Read-only overlay that proves the plugin can introspect and visualize the block tree on real pages.
**Ships**:
- Plugin scaffold; gated by `wireframe_enabled` site setting + `wireframe_allowed_groups`.
- **Plan archive**: `plugins/discourse-wireframe/docs/PLAN.md` — copy of this planning document, committed alongside the scaffold so the architectural intent travels with the code regardless of session state. Updated as the plan evolves.
- **Entry point**: floating "Edit page" pill at bottom-right via `api.renderInOutlet("above-footer", …)`. Visible only to permitted users on pages with at least one `<BlockOutlet>`.
- Selection chrome on hover/click via `debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, …)` — patterned on `frontend/discourse/app/static/dev-tools/block-debug/patch.js`.
- Read-only right panel: shows selected block's metadata.
- Read-only left panel: outline tree of `BlockOutlet` layouts on the current page, fed by `services/blocks.js#listOutlets()` + `hasLayout(outletName)`.

**Out of scope**: any drag, mutation, persistence, palette, FormKit, PluginOutlets, new core APIs, theme-admin entry point, **automated tests** (deferred to Phase 2 — see below).
**Why now**: smallest viable thing. Validates the in-place overlay against real Discourse pages. The in-context pill is the lightest possible entry; theme-admin entry waits until Phase 3 when there's something to save. Committing the plan archive in this phase guarantees the architecture is preserved before any core changes ship.
**Verification**: lint plus manual smoke (enter editor, click a block, confirm inspector + outline sync). Automated test coverage for Phase 1's read-only surface is backfilled at the start of Phase 2 — see Phase 2's "Ships" list.

### Phase 2 — "Edit args of an existing block"
**Goal**: Select a block, change its args via FormKit-rendered inspector, see the change live (in-memory only).
**Ships**:
- **Core change #1** (UI hints in `ArgSchema`).
- FormKit-from-schema mapper.
- Editor service mutates args; reactivity propagates through `createBlockArgsWithReactiveGetters` (`decorator.js:328`).
- Undo/redo (in-memory).
- Reset button (no persistence yet).
- **Test backfill for Phase 1's surface** (deferred from Phase 1):
  - qunit unit tests for `WireframeService` (`canEdit` matrix, `isBlockSelected`, `selectBlock`).
  - qunit integration test for `EntryPill` (visibility under setting / group / active combinations).
  - Acceptance test: enable plugin, register a layout against a fixture block, enter editor mode, click a block, assert inspector populates and outline highlights.
- Phase 2's own tests: schema → form mapping, arg-mutation propagation, undo/redo stack.

**Out of scope**: moving blocks, adding/removing blocks, persistence, conditions UI, palette.
**Why now**: forces the FormKit→schema mapping that everything else depends on, before harder work. Backfilling Phase 1 tests here keeps Phase 1 itself minimal while getting full coverage in place before mutation lands.

### Phase 3 — "Persistence as ThemeFields + theme-admin entry"
**Goal**: Save edits to ThemeFields on the active theme; layouts coexist with statically-registered ones via the resolution chain. Add the canonical entry point from the theme admin page.
**Ships**:
- **Core changes #3, #6, #7, #8** (replaceLayout / resolution chain, `block_layout` ThemeField type, auto-child-theme policy, MessageBus reload).
- Plugin-side persistence service: serializes editor draft → ThemeField JSON; calls `Themes::SaveBlockLayout` Rails service; rebakes; broadcasts.
- **Theme-admin entry**: "Wireframe" button on `/admin/customize/themes/:id` with a page-picker.
- Save / preview / discard UI in toolbar.
- "Reset to default" = delete the ThemeField (falls back to parent theme or code default via the chain).
- Admin-only.

**Out of scope**: drag-drop, palette, conditions UI, scoped overrides beyond theme/child, import/export, patterns.
**Why now**: persistence is the highest-risk core change. Doing it before drag-drop forces clean resolution-chain semantics. Even without dnd, this is *useful*: admins can tweak existing layout args and save, with edits naturally tracked alongside the theme.

### Phase 4 — "Drag-drop within and between containers"
**Goal**: Move existing blocks; rearrange children inside containers; reorder root-level blocks.
**Ships**:
- Pragmatic dnd integration. Two Ember modifiers: `editor-draggable`, `editor-droppable`. Single absolute-positioned drop indicator managed by editor service.
- Visual drop zones (3px horizontal bars + plus-button between siblings).
- Cross-container moves only when allowed by `childArgs` / slots / `allowedOutlets` / `deniedOutlets`.
- Layout-mutation library (immutable insert/move/remove on `LayoutEntry[]` trees).
- Keyboard: `M` for move mode, arrow keys, `Esc` cancel, `Cmd+X`/`Cmd+V` cut/paste.

**Out of scope**: palette (insertion from outside the canvas), conditions UI, multi-slot containers, outlet-renderer bridge.
**Why now**: dnd is moderate effort; doing it after persistence means moves *stick*.

### Phase 5 — "Tolerant intermediate states"
**Goal**: The editor's `session-draft` layer accepts every kind of validation failure without crashing the page; invalid blocks ghost-render with hint messages and recovery actions; save proceeds even with warnings.

**Why this is its own phase**: Phase 4 made it possible to drag the only child out of a container and crash the page. Phase 6's palette-driven deletes will hit the same surface from every direction (delete a block, leave its container empty; paste a subtree with a typo; etc.). Phase 8's JSON import multiplies it further. Phase 5 is the foundation that makes 6+ safe.

**Ships**:
- **Permissive validation mode** in `frontend/discourse/app/lib/blocks/-internals/validation/` — every `raiseBlockError` call site converts to "mark the entry with `__failureType` / `__failureCode` / `__failureReason` and continue". Strict mode (code-default, theme, server-side install paths) is unchanged.
- New `FAILURE_CODE` enum covering: empty container, missing required arg, type mismatch, allowed/denied-outlets violation, container-args mismatch, cross-arg constraint failure, unknown block (typo), malformed condition, unknown entry key, invalid id, stable-key collision, depth-exceeded, cycle.
- `_setLayoutLayer({ permissive: true })` wired through `createLayerEntry`'s lazy `validatedLayout` getter; `BlockOutlet.children` resolves with marked entries instead of rejecting.
- `BlockOutletRootContainer#preprocessEntries` honours `__failureType: "structural-invalid"` and renders ghost blocks (always, when the editor is active — not gated on dev-tools `showGhosts`).
- New `<UnknownBlockPlaceholder>` core component for the typo case — labelled card showing the bad block name, `Swap` affordance.
- Editor UX: per-entry inline hint on the canvas, inspector banner with per-`__failureCode` recovery actions (`Remove empty container`, `Swap block`, `Edit conditions`, …), toolbar warnings tally with "Locate" links, first-time-with-warnings save dialog (with "Don't ask again" preference).
- Server-side: `Themes::SaveBlockLayout` runs validation permissively, persists invalid layouts as-is, logs soft failures.

**Out of scope**: auto-removal of empty containers; pre-validating drag operations to reject mid-flow invalid states; validation-blocking save.

**Why now**: Phase 4 surfaces the problem; Phase 6 amplifies it. The pattern ports cleanly to JSON import (Phase 8). Implementing it once here pays off in every later phase.

### Phase 6 — "Palette: add and remove blocks"
**Goal**: Drag from a palette into the canvas; delete and copy/paste subtrees.
**Ships**:
- **Core changes #2, #4** (block discovery metadata, preview-token authorization).
- Left-rail palette: search, category filter, drag source. Tabs: `Blocks`, `Patterns` (empty in this phase), `Outlets` (Phase 7).
- Categorization driven by `metadata.namespaceType` + optional `category` field.
- Block insertion mutations.
- Plugin-shipped starter block library (heading, paragraph, image, columns, callout, button-link, recent-topics, badges-grid). All built on ui-kit atoms.

**Out of scope**: conditions UI, outlet routing, import/export, patterns.
**Why now**: this is what makes it *feel* like Puck/Gutenberg. A starter block library proves the editor isn't useless on a vanilla install.

### Phase 7 — "Conditions, condition-only simulation, multi-outlet awareness"
**Goal**: Editors can attach conditions to blocks; preview how condition-gated blocks render under a different persona or viewport; navigate between Block Outlets on a page in one editing session.
**Ships**:
- **Core change #5** (Block Outlet enumeration metadata) — outlets carry `displayName`, `description`, `category` in addition to the name. `services/blocks.js#listOutletsWithMetadata()` exposes the unified shape for both core + custom outlets.
- **Condition-type discovery**: `services/blocks.js#listConditionTypes()` returns every condition class with its `displayName`, `description`, and `argsSchema`, sourced from a new `displayName` / `description` field on the `@blockCondition` decorator.
- Visual condition builder UI in the inspector (an editable cousin of `dev-tools/block-debug/conditions-tree.gjs`) — AND / OR / NOT combinators with per-leaf arg inputs driven by the discovered schema.
- Persona switcher (Real / Anonymous / TL0–TL4 / Admin) + viewport switcher (Real / Mobile / Tablet / Desktop) in the toolbar, threaded through the condition evaluator via a new `context.simulation` field. `user.js` and `viewport.js` honor it; other condition types are unchanged.
- Greyed-out "ghost" rendering for condition-failed blocks during sim (reuses Phase 5's GHOST_BLOCKS callback path — no new code).
- Outlets tab in the left rail + an outlet jump dropdown in the toolbar — both fed by `listOutletsWithMetadata()`.

**Scope decision** (condition-only simulation): the persona/viewport toolbar swaps the evaluator's identity inputs, but block *bodies* still render with the real user's data. A `"Welcome, {{username}}"` block keeps the real username under sim mode. Verifying condition-driven visibility is what authors most need to preview; full-fidelity preview (service shadowing so block bodies see the simulated user) is deferred to a later phase since it has a much bigger blast radius across core.

**Out of scope**: full-fidelity preview (deferred), patterns, import/export, multi-slot containers, per-instance Style tab, route / setting simulation. PluginOutlets remain explicitly out of scope project-wide.
**Why now**: conditions unlock targeting (admin-only banners, mobile-only blocks). Multi-outlet awareness makes editing a "page" rather than a single outlet feel coherent.

### Phase 8 — "Patterns, per-instance styling, import/export, polish"
**Goal**: Reusable compositions, structured per-instance styling, JSON portability, A11y.
**Ships**:
- **Patterns**: select a subtree → save as a named pattern stored as a separate ThemeField type (`block_pattern`). Browseable in palette `Patterns` tab. Shipped with the theme bundle.
- **"Style" inspector tab** with bounded controls (padding, margin, color, border, typography) writing to scoped CSS variables. **Core change #1** extends to a separate `style:` schema namespace alongside `args:`.
- **Import/export**: JSON files with `schema_version`. Round-trippable.
- Starter community pattern pack (homepage variants, sidebar configs).
- Optional dedicated `/admin/customize/wireframe` route with a page-picker sidebar — still uses in-place rendering.
- A11y pass (keyboard, screen-reader announcements, focus management).
- "Mobile too small" fallback message for screens < 1024px.

**Out of scope**: widget API customizations (deferred — widgets are deprecated). Multi-slot containers (defer further if no demand).

---

## Editor UX (canonical layout)

```
+-------------------------------------------------------------------------------------------+
| [D]  Editing: Homepage   [Outlet▼]  [Persona: Anon▼] [󰍹󰓅󰏚]  [↶][↷]  Preview Discard Save |
+--------+----------------------------------------------------------------------+----------+
| Pal/Out|                                                                      |Inspector |
| /search|        h e r o - b l o c k s   (outlet boundary)                     |          |
|--------|   .................................................................. |Hero      |
|[Blocks]|   . [≡] hero-banner   ⚙   [ selected — solid outline ]            .  |Banner    |
|[Patrns]|   .................................................................  |          |
|        |     ───── + ──── (drop zone bar) ───────────────────────────────     |Show when:|
| Core   |   .................................................................. |  (none)  |
| ▸ hero |   . [≡] block-group  📦 (container — dotted inside)        [⚠ 1] .  |          |
| ▸ feat |   .   ┌------------------------------------------------------┐    .  |Args      |
|        |   .   |  [≡] feature-card             [↑][↓][⧉][⌫]          |    .  |Title [..]|
|--------|   .   |  [≡] feature-card  [! hidden by conditions]          |    .  |Color [..]|
|Plugin  |   .   └------------------------------------------------------┘    .  |          |
| ▸ chat |   ..................................................................|Children  |
|--------|        h o m e p a g e - b l o c k s   (collapsed)                  |receive:  |
|Theme   |                                                                      | …        |
| ▸ feat |                                                                      |          |
|        |                                                                      |Advanced  |
|        |                                                                      | id  [..] |
|        |                                                                      | class[..]|
+--------+----------------------------------------------------------------------+----------+
   280px                              ~auto (canvas)                              320px
```

**Surface principles**:
- In-place editing on the actual page. Selection / drag / drop chrome appears via `debugHooks` patches; idle pages look identical to today.
- Block boundaries: invisible idle, dashed-outline on hover, solid-outline + handle on select. Containers always show a faint dotted inner outline.
- Drop zones: only appear during active drag — 3px accent bars between siblings + plus-button gap affordance.
- Outlets get a labeled boundary chrome so admins see they edit multiple outlets in one session.
- Conditional blocks render as ghosts when persona/viewport simulation doesn't satisfy their condition; still selectable & editable.

**Inspector default control mapping** (overridable via `ui:` hint):
- `string` → text; `string + maxLength>200` → textarea; `string + enum` → select.
- `number` → number input; `boolean` → toggle.
- `array.itemType:string` → tag-chooser; `array of objects` → FormKit collection.
- `format: "color" | "icon" | "emoji" | "image" | "richtext"` → corresponding picker.
- `type: "any"` → code editor.

**Conditions inspector**: collapsible "Show this block when…" panel above args. Top-level AND/OR toggle, per-row `[type ▼] [params…]`, wrap-in-NOT and wrap-in-group buttons. Live green/red dot showing whether the condition currently passes for the simulated persona.

**Mobile**: editor itself is desktop-only (≥1024px). Below threshold, show a "use desktop, or use the JSON layout editor" message.

---

## Plugin layout

```
plugins/discourse-wireframe/
  plugin.rb
  README.md
  docs/
    PLAN.md                          # copy of the planning document — committed alongside scaffold (Phase 1)
  config/{settings.yml, locales/}
  app/{controllers,services,models,serializers}/wireframe/
  assets/javascripts/discourse/
    api-initializers/
      register-editor-blocks.js      # registers outlet-renderer + plugin's starter block library
    services/
      editor.js                      # selection, dirty, history, simulated persona/viewport
      editor-persistence.js          # CRUD against the theme-field-backed save endpoint
      editor-clipboard.js
      patterns.js
    components/editor/
      shell.gjs                      # toolbar + 3-pane shell
      palette.gjs                    # left rail tab 1
      tree-outline.gjs               # left rail tab 2
      inspector.gjs                  # right rail (FormKit-driven)
      canvas-overlay.gjs             # selection chrome via debugHooks
      conditions-builder.gjs         # visual AND/OR/NOT editor
      style-tab.gjs                  # Phase 8
      history.gjs
    components/fields/                # editor-only FormKit field types not in core
      color-picker.gjs
      icon-picker.gjs
    modifiers/{editor-draggable,editor-droppable}.js
    lib/{dnd-monitor,layout-mutations,serialize,undo-stack}.js
    routes/admin-wireframe.js    # Phase 8 — dedicated entry
  spec/system/wireframe_spec.rb
  spec/requests/admin/wireframe_save_spec.rb
  test/javascripts/                  # qunit
```

---

## Critical files to study

- `frontend/discourse/app/blocks/block-outlet.gjs` — `_renderBlocks`, the `outletLayouts` map, `BlockOutlet#validatedLayout`. Heart of the resolution-chain change.
- `frontend/discourse/app/lib/blocks/-internals/decorator.js` — `@block` decorator, `BlockMetadataEntry`, `BlockComponentManager` (preview-token bypass goes here).
- `frontend/discourse/app/lib/blocks/-internals/registry/block.js` — block registry + freeze semantics.
- `frontend/discourse/app/lib/blocks/-internals/registry/outlet.js` — outlet registry (gets metadata extension).
- `frontend/discourse/app/lib/plugin-api.gjs` — public API surface; new `api.replaceLayout`, `api.createBlockPreviewToken`, `api.registerBlock` extensions.
- `frontend/discourse/app/services/blocks.js` — public introspection service; gets `listBlocksWithMetadata` enrichment + `listOutlets({ withMetadata: true })`.
- `frontend/discourse/app/static/dev-tools/block-debug/patch.js` — *reference implementation* for the editor's selection-chrome patching pattern; mirror, don't modify.
- `frontend/discourse/app/static/dev-tools/state.js` + `toolbar.gjs` — pattern for sessionStorage-persisted, `@tracked`-singleton state + draggable mounted toolbar.
- `frontend/discourse/app/blocks/conditions/` — existing condition types whose schemas drive the conditions builder.
- `frontend/discourse/app/form-kit/` — FormKit; underlies the property inspector. 37 control types already.
- `frontend/discourse/app/modifiers/draggable.js` — existing drag primitive (kept for simple cases; replaced by Pragmatic dnd modifiers for the editor canvas).
- `app/models/theme.rb` + `app/models/theme_field.rb` — register the new `block_layout` ThemeField type and the auto-child-component policy.
- `app/serializers/site_serializer.rb` — push the active theme stack's block layouts to the client.
- `spec/fixtures/themes/dev-tools-test-theme/javascripts/discourse/pre-initializers/register-test-blocks.gjs` — real-world block fixture for system spec setup.

---

## Open questions for the user

1. **First-party plugin or community plugin?** First-party = we coordinate the core PRs (#1–#9 above) alongside plugin work. Community = either avoid core changes (hard) or push them upstream as separate work and version-gate the plugin. Default assumption: first-party.
2. **Replace the admin theme editor or live alongside?** Theme editor handles CSS/JS source code; wireframe handles layout. Recommend alongside, with a unified `/admin/customize` landing surfacing both.
3. **Widget API customizations in scope?** Legacy `decorateWidget` is largely orthogonal and being phased out. Recommend explicit out-of-scope. (PluginOutlets are also out of scope — see the Scope section.)
3a. **Should we ship a "Block Outlet conversion guide"** alongside this plugin to help core/plugin authors migrate `<PluginOutlet>` positions to `<BlockOutlet>`? Without that nudge, the editor's surface stays small.
4. **Per-page edits as a first-class concept?** A user might want different homepages on `/`, `/categories`, `/tags`. The `route` block condition already enables this. Question: dedicated "page selector" UX, or rely on conditions? Recommend conditions for v1.
5. **Mobile-editor support?** Recommend desktop-only (≥1024px) for v1; the viewport simulator in the toolbar already lets desktop admins preview mobile layouts.
6. **Layout localization?** Block args may include user-facing strings. No convention for "this string is translatable" today. Cheap to future-proof the JSON to support `{ key: "…" }` references; deciding the i18n flow is a separate design.
7. **Optimistic vs. pessimistic conflict resolution** when two admins edit the same theme simultaneously? Recommend optimistic with the ThemeField's existing `updated_at` for conflict detection.
8. **Telemetry?** Anonymous usage — which blocks are most-dragged, where edits happen — would inform future block library design. Privacy implications.

---

## Verification plan

End-to-end success criteria, scoped per phase:

- **Phase 1**: enable plugin → click toolbar button → hover any block on homepage → outline appears, panel shows metadata. No regression in non-editor mode.
- **Phase 2**: select a registered block → inspector renders form from schema → change a string arg → canvas updates within 250ms → undo restores. Reload loses the edit (no persistence yet).
- **Phase 3**: edit args, save → reload → edit persists. Verify a `block_layout` ThemeField was created on the active theme. Save edits against a Git-imported theme → verify a child theme component was auto-created and the field landed there. Two browser tabs: edit + save in tab A → tab B reflects within ~1s via MessageBus. Resolution chain: a code-registered layout is overridden by a saved theme layout.
- **Phase 4**: drag a block within a container → reorders. Drag across containers when allowed → moves; when disallowed, drop is rejected with a toast. Keyboard: select → `M` → arrow keys → `Enter` confirms move.
- **Phase 5**: drag the only child out of a `block-group` → container ghosts with a hint, page doesn't crash; the toolbar shows a "1 issue" tally. Click the inspector's "Remove empty container" → ghost replaced. Corrupt a saved layout's `block` field via the rails console (`hero-banner` → `hero-bannr`) → reload → corrupted entry shows a labelled placeholder; `Swap` action wires through to a real block.
- **Phase 6**: open palette → search → drag a starter block onto the canvas → inserts. Delete via handle. Copy via `Cmd+C` → paste → duplicates.
- **Phase 7**: switch persona to Anonymous → admin-only blocks ghost out. Switch viewport to Mobile → viewport-mobile blocks materialize. Add a `route` condition via builder → save → block only renders on chosen routes.
- **Phase 8**: select a subtree → save as pattern → reopen palette → pattern available → drag inserts the subtree. Per-instance Style tab: change padding → reflected in CSS variable → reset returns to default. Export a layout to JSON → reset → import JSON → restored exactly. Change active theme → only the matching layouts apply.

**Tests strategy**:
- qunit for editor service mutations, layout-mutation library, undo-stack, schema → form mapping (pure logic).
- rspec request specs for the save endpoint; rspec service specs (`Service::Base`) for save/publish/import.
- One full-flow system spec per phase: "admin opens editor, performs the goal, saves, reloads, verifies persistence."
- Avoid covering every micro-interaction in system specs — slow and brittle.

**Linting**: `bin/lint` after each change; `bin/rspec`, `bin/qunit` per surface.
