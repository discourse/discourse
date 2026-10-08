# Inline text editing for heading and paragraph blocks

## Context

The discourse-wireframe plugin currently edits all block content through the right-hand inspector form (FormKit). For text blocks (`wf:heading`, `wf:paragraph`), this means: click the block on the canvas → focus shifts to the inspector → type in a text field → see the change reflected on the canvas. This is fine for structural args (alignment, level, icon) but feels wrong for the text itself, where the natural gesture is to click on the heading and start typing.

The goal is **click-on-selected → edit in place**, with **bold / italic / link** marks available. The implementation should be factored as a **reusable primitive** so future text-bearing blocks (button label, callout body, image caption, etc.) can adopt it without re-inventing the wheel.

Exploration confirmed Discourse's ProseMirror integration is modular: we can mount it with a custom subset schema (only `text`, `hard_break`, `strong`, `em`, `link`), toggle editable mode via `@disabled`, and round-trip cleanly — all without dragging in the composer's toolbar, draft system, or post-specific plugins. An existing test (`prosemirror-editor-test.gjs:45-60`) already mounts a minimum-schema editor.

## Design

### Storage: polymorphic `string | doc-JSON` with lazy upgrade

`args.text` accepts either a **plain string** (for unformatted content, today's shape) or a **ProseMirror doc-JSON object** (when marks are present). The shape stays a string until a mark is actually applied; it downgrades back to a string when the last mark is removed.

```jsonc
// Plain — common case, hand-author-friendly
"text": "Hello world"

// With marks — produced only when needed
"text": {
  "type": "doc",
  "content": [
    { "type": "text", "text": "Hello " },
    { "type": "text", "text": "world", "marks": [{ "type": "strong" }] }
  ]
}
```

Why this shape:
- **doc-JSON is ProseMirror's own format**, so `state.doc.toJSON()` ↔ storage is identity. No serializer to maintain, no parse step on read.
- **Plain strings stay plain** for the common case. Existing layouts need zero migration. Hand-authoring `"text": "Hello"` keeps working.
- **Security is enforced by schema validation**, not render-time sanitization. Text is always text-escaped by Glimmer; the only attack surface is the link `href`, which gets explicit URL validation.

Helpers (live in the plugin next to the schema definition):

```js
// Normalize on the way into the editor
function toDoc(value) {
  if (typeof value === "string") {
    return { type: "doc", content: value ? [{ type: "text", text: value }] : [] };
  }
  return value;
}

// Downgrade on the way out — produces a string if there are no marks/hard_breaks
function toStorage(doc) {
  const onlyPlainText = doc.content?.every(
    (n) => n.type === "text" && (!n.marks || n.marks.length === 0)
  );
  return onlyPlainText ? doc.content.map((n) => n.text).join("") : doc;
}
```

**Rule:** normalize once at the editor boundary; never branch on shape downstream.

### Validator integration: new `richInline` core type

The block validator (`frontend/discourse/app/lib/blocks/-internals/validation/args.js`) has a frozen, hardcoded type set (`string | number | boolean | array | object | any`) with no plugin extension point. Adding a polymorphic type cleanly requires a small core change:

1. Add `"richInline"` to `VALID_ARG_TYPES`.
2. Add a switch case in `validateArgValue()`:
   ```js
   case "richInline":
     if (typeof value === "string") break;
     if (isInlineDoc(value)) break;
     return argValidationError(argName, "must be a string or rich-text doc");
   ```
3. `isInlineDoc` lives in the plugin and structurally checks `{ type: "doc", content: [...] }` with only `text` / `hard_break` nodes and an enum of `strong | em | link` marks. Unknown marks, foreign nodes, or invalid `href`s are rejected.

This is a small, well-bounded core change. The type is reusable — any future block-based plugin will benefit. (A registry-based alternative — `registerBlockArgType()` — was considered and deferred. Worth doing if a second consumer appears; not needed for this work.)

Validator stamps (`__failureType` / `__failureReason` / `__visible`) require no new wiring: the existing `markEntrySoftFailure` / `clearValidatorStamps` flow picks up the new type case automatically. Hand-authored garbage in `args.text` gets stamped; an edit clears the stamp.

### Block declarations

```js
args: {
  text: {
    type: "richInline",
    default: "Heading",                 // string default; lazy upgrade leaves it a string
    ui: { control: "rich-inline" },
  },
  // existing structural args (level, align, icon, etc.) unchanged
}
```

### Rendering: dumb block + dumb renderer, editor chrome handles edits

**Design principle (matches the image-block pattern):** block components are pure renderers. They don't know about selection, edit mode, or the wireframe service. The editor chrome wraps blocks and overlays editing UI on top.

The components split into two groups:

**Shared / live-site (dumb, no service):**
```
wf-heading.gjs / wf-paragraph.gjs       (chooses <h1..h6> / <p>, applies block styles)
  └─ <InlineRichTextRenderer>           (walks the doc, emits inline DOM + data-attrs)
      └─ <MarkedText>                   (recursive mark wrapper: <strong>, <em>, <a>)
```

**Admin-only (the editor chrome):**
```
<EditorCanvas>                          (existing — owns selection/keys/clicks/wrapper)
  └─ <InplaceTextController>             (new — watches service state, mounts editor on the active region)
      └─ <ProsemirrorEditor>            (rendered via {{in-element}} into the active renderer's span)
```

**Read-only path (live site + admin canvas when not editing).** `<InlineRichTextRenderer>` walks `content` (a plain string is treated as a single-run array). The recursive `<MarkedText>` applies marks; Glimmer's text-content escaping handles XSS. No `cook()`, no async, no flash. The renderer tags its root element with data-attrs so the editor chrome can find it — these are inert on the live site (nothing listens).

```gjs
// InlineRichTextRenderer.gjs — outer walk
// Props: @arg (the argName, used as a marker), @schema, @value
<template>
  <span
    data-wf-rich-text-arg={{@arg}}
    data-wf-rich-text-schema={{@schema}}
    ...attributes
  >
    {{#each (this.runs @value) as |run|}}
      {{#if (eq run.type "hard_break")}}
        <br />
      {{else}}
        <MarkedText @text={{run.text}} @marks={{run.marks}} />
      {{/if}}
    {{/each}}
  </span>
</template>

// `this.runs(value)` returns:
//   - [{ type: "text", text: value, marks: [] }]  when value is a string
//   - value.content                                when value is a doc
```

```gjs
// MarkedText.gjs — recursive mark wrapper
<template>
  {{#if (eq @marks.length 0)}}
    {{@text}}
  {{else}}
    {{#let (this.head @marks) (this.tail @marks) as |m rest|}}
      {{#if (eq m.type "strong")}}
        <strong><MarkedText @text={{@text}} @marks={{rest}} /></strong>
      {{else if (eq m.type "em")}}
        <em><MarkedText @text={{@text}} @marks={{rest}} /></em>
      {{else if (eq m.type "link")}}
        <a href={{this.safeHref m.attrs.href}} rel="noopener nofollow ugc">
          <MarkedText @text={{@text}} @marks={{rest}} />
        </a>
      {{else}}
        <MarkedText @text={{@text}} @marks={{rest}} />
      {{/if}}
    {{/let}}
  {{/if}}
</template>
```

`safeHref` passes the URL through Discourse's URL validation; on failure it returns `#`. This is the one and only attack surface in the renderer.

Mark order is determined by the ProseMirror schema's `markSpec` ordering (canonical, e.g., `[strong, em]` always nests as `<strong><em>…</em></strong>`).

**Edit path (admin-only).** The editor chrome wraps each block in a shell with `data-wf-block-id={{entry.id}}` (the wrapper already exists for selection/drag chrome). A canvas-level click handler does the gesture:

```js
onCanvasClick(event) {
  const target = event.target.closest("[data-wf-rich-text-arg]");
  if (!target) return;
  const blockEl = target.closest("[data-wf-block-id]");
  if (!blockEl) return;
  const blockKey = blockEl.dataset.wfBlockId;
  if (this.wireframe.selectedBlockKey !== blockKey) return;  // click-on-selected gesture
  this.wireframe.startEditingArg(blockKey, target.dataset.wfRichTextArg);
}
```

A new `<InplaceTextController>`, mounted once at the canvas level, watches `(editingBlockKey, editingArgName)`. When set, it locates the active renderer span, reads `data-wf-rich-text-schema` to pick the PM extension list, and mounts a `<ProsemirrorEditor>` into that span via `{{in-element}}`. The renderer's content is hidden (via a class toggle) while the editor is mounted, so the user sees the PM editor exactly where the rendered text was — same parent (`<h2>`, `<p>`), same styles.

```gjs
// InplaceTextController.gjs — admin chrome, mounted once at canvas level
<template>
  {{#if this.activeRendererEl}}
    {{#in-element this.activeRendererEl}}
      <ProsemirrorEditor
        @value={{this.docValue}}
        @valueFormat="json"
        @disabled={{false}}
        @includeDefault={{false}}
        @extensions={{this.extensionsForSchema}}
        @change={{this.handleChange}}
        @onSetup={{this.handleSetup}}
      />
    {{/in-element}}
  {{/if}}
</template>
```

`handleChange` calls `wireframe.updateBlockArg(blockKey, argName, toStorage(docJson))`. Escape, blur to outside the block, and outside-clicks call `wireframe.stopEditing()`. The toolbar is mounted as a child of the controller, so it lives and dies with the editor.

Adding inline edit to a new block is a one-line template change: drop in `<InlineRichTextRenderer @arg="…" @schema="…" @value={{@…}} />`. The block author never touches editing code.

Lazy mount = the live site never pays ProseMirror's startup cost; even in admin, only the currently-edited arg mounts PM.

### Editing state on the service

`WireframeService` already tracks `selectedBlockKey` and exposes a full undo/redo system (`_undoStack`, `_redoStack`, `undo()`, `redo()`, `_recordStructural()`, and args-shape undo entries `{ kind: "args", entry, prev, next }`). Inline edit integrates with this:

```js
@tracked editingBlockKey = null;
@tracked editingArgName = null;
_editingPrevSnapshot = null;   // args snapshot taken when edit started

startEditingArg(blockKey, argName) {
  const entry = this._findEntry(blockKey);
  this._editingPrevSnapshot = structuredClone(entry.args);
  this.editingBlockKey = blockKey;
  this.editingArgName = argName;
}

// Called per keystroke from PM's @change.
// Mutates without pushing undo — PM's internal undo handles in-session granularity.
applyInlineEditChange(value) {
  const entry = this._findEntry(this.editingBlockKey);
  entry.args[this.editingArgName] = value;
}

stopEditing({ commit = true } = {}) {
  if (!this.editingBlockKey) return;
  const entry = this._findEntry(this.editingBlockKey);
  if (commit) {
    const next = structuredClone(entry.args);
    if (!isEqual(this._editingPrevSnapshot, next)) {
      this._undoStack.push({ kind: "args", entry, prev: this._editingPrevSnapshot, next });
      this._redoStack.length = 0;
    }
  } else {
    entry.args = this._editingPrevSnapshot;   // revert
  }
  this.editingBlockKey = null;
  this.editingArgName = null;
  this._editingPrevSnapshot = null;
}
```

A specific arg is in active edit mode iff `editingBlockKey === entry.id && editingArgName === thisArgName`. The pair `(blockKey, argName)` scales naturally to blocks with many text fields — no shape change needed.

**Undo integration.** Per-keystroke mutations bypass the undo stack (via `applyInlineEditChange`, not `updateBlockArg`). PM's internal undo handles Cmd+Z while the editor is focused. On commit, `stopEditing` pushes exactly one `{ kind: "args" }` undo entry capturing the whole edit session. The existing canvas-level Cmd+Z handler is suspended while `editingBlockKey` is set, so the keystroke always reaches PM first.

The inspector form keeps using the existing `updateBlockArg`-style path (one undo entry per change), which is appropriate for form-driven edits. Both paths end up in the same `_undoStack`.

### Schema variants

Three `@schema` variants govern what's allowed in each field:

| `@schema` | Marks | Line breaks | Used for |
|---|---|---|---|
| `"plain"` | none | none (Enter commits) | Labels, names, short titles |
| `"heading"` | strong, em, link | none (Enter commits) | Single-line rich content (`wf:heading` text, `wf-media-card` title) |
| `"paragraph"` | strong, em, link | `hard_break` (Enter inserts) | Multi-line rich content (`wf:paragraph` text, `wf-cta-banner` content, `wf-callout` body) |

`@schema` is emitted as a data-attr on the renderer span; the `InplaceTextController` reads it to pick the right PM extension list and toolbar config when entering edit mode. `"plain"` has no toolbar (no marks). For a `"plain"` arg, `toStorage` always returns a string — the doc-JSON upgrade path is unreachable because no marks can be applied.

### Click-to-edit gesture (canvas-owned)

- Block not selected → click selects it (existing behavior, unchanged).
- Block selected → click on an element with `data-wf-rich-text-arg` → canvas calls `wireframe.startEditingArg(blockKey, argName)`. This implicitly commits + exits any other arg currently being edited.
- Escape, blur to outside the block, or click outside → canvas calls `wireframe.stopEditing()`.
- The inspector form works in parallel; both paths write through `updateBlockArg` and stay in sync via the existing `trackedObject` reactivity.

When switching between fields in the same block, the canvas-level click handler runs `startEditingArg` *before* the previous editor's blur fires, so there's no "back to null" intermediate state.

### Toolbar

Small floating bubble (bold / italic / link) appears on non-empty text selection in any non-`plain` editor. Built by subclassing `ToolbarBase` (`frontend/discourse/app/lib/composer/toolbar.js`), modeled on `frontend/discourse/app/static/prosemirror/extensions/link-toolbar.js`. Keyboard shortcuts (`Cmd+B`, `Cmd+I`, `Cmd+K`) come free from ProseMirror's default keymap.

### Inspector form control

`ui.control: "rich-inline"` gets a new branch in `schema-to-fields.js`'s `pickControl()`. First cut: a small read-only preview of the current content as flattened markdown (`"Hello **world**"`) plus a hint that the field is edited on the canvas. A fallback editable text field can come later for headless / no-canvas editing.

---

## Phase 1 — Foundation (primitive + heading + paragraph)

Ships the new primitive, the editor controller, the validator type, and adoption on the two simplest text blocks. This is the proving ground for the design; Phase 2 is mostly find-and-replace once it lands.

**New — shared / live-site (dumb, no service):**
- `plugins/discourse-wireframe/assets/javascripts/discourse/components/rich-text-renderer.gjs` — Props: `@arg`, `@schema`, `@value` (`string | doc-JSON`). Emits `<span data-wf-rich-text-arg data-wf-rich-text-schema>` and walks runs via `<MarkedText>`.
- `plugins/discourse-wireframe/assets/javascripts/discourse/components/marked-text.gjs` — recursive mark wrapper. Renders `<strong>`, `<em>`, `<a>`. `href` passes through `safeHref`.
- `plugins/discourse-wireframe/assets/javascripts/discourse/lib/rich-text.js` — `isInlineDoc`, `toDoc`, `toStorage`, `safeHref`, and a `SCHEMAS` map of `{ plain, heading, paragraph } → ProseMirror extension list`.
- `plugins/discourse-wireframe/assets/stylesheets/common/rich-text.scss` — renderer span styling, the `is-editing` class that hides renderer content while the editor mounts inside it, focus ring, placeholder.

**New — admin-only (editor chrome):**
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inplace-text-controller.gjs` — mounted once at canvas level. Watches `(editingBlockKey, editingArgName)`; locates the matching renderer span; mounts `<ProsemirrorEditor>` into it via `{{in-element}}`. Reads `@schema` off the renderer's data-attr to pick the extension list. Handles `@change → updateBlockArg`, Escape / outside-click → `stopEditing`.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inline-edit-toolbar.gjs` — bold / italic / link bubble menu, subclasses `ToolbarBase`. Mounted by the controller; only when `schema !== "plain"`.

**Modified — core:**
- `frontend/discourse/app/lib/blocks/-internals/validation/args.js` — add `"richInline"` to `VALID_ARG_TYPES`; add the switch case calling out to `isInlineDoc`.

**Modified — plugin:**
- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-heading.gjs` — replace `{{@text}}` with `<InlineRichTextRenderer @arg="text" @schema="heading" @value={{@text}} />` (wrapped in the heading tag). Change `args.text.type` from `"string"` to `"richInline"`.
- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-paragraph.gjs` — same change with `@schema="paragraph"` (the outer `<p>` stays in the block template).
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe.js` — add `@tracked editingBlockKey`, `@tracked editingArgName`, `_editingPrevSnapshot`; methods `startEditingArg`, `stopEditing` (with undo-entry push on commit), `applyInlineEditChange` (per-keystroke, no undo push), `updateBlockArg` (split from `updateSelectedArg`).
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/schema-to-fields.js` — add `"rich-inline"` branch in `pickControl()`.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/canvas.gjs` — add the canvas-level click handler that matches `[data-wf-rich-text-arg]` inside the selected block; render `<InplaceTextController />` once at canvas level; wire Escape / outside-click to `stopEditing`; suspend the canvas-level Cmd+Z handler while `editingBlockKey` is set.

**Reusable utilities (do not re-implement):**
- `<ProsemirrorEditor>` at `frontend/discourse/app/static/prosemirror/components/prosemirror-editor.gjs` — `@includeDefault={{false}}`, `@extensions`, `@disabled`, `@change`, `@onSetup`.
- `ToolbarBase` at `frontend/discourse/app/lib/composer/toolbar.js` and the link-toolbar reference pattern.
- The existing `entry.args` `trackedObject` mutation flow — inline edit and inspector write through the same path, no new sync code.
- Validator stamps lifecycle in `mutate-layout.js` (`clearValidatorStamps`, `markEntrySoftFailure`) — works as-is once the `richInline` type is added.

**Verification:**
1. **Validator unit test** — `frontend/discourse/tests/unit/lib/blocks/validation/args-test.js` (or adjacent): `type: "richInline"` accepts a plain string, accepts a valid doc-JSON, rejects unknown marks, rejects foreign node types, rejects invalid `href` values.
2. **Renderer component test** — `plugins/discourse-wireframe/test/javascripts/components/rich-text-renderer-test.gjs`:
   - Renders a plain string as text.
   - Renders a doc-JSON with marks → `<strong>`, `<em>`, `<a>` wrapping.
   - Emits `data-wf-rich-text-arg` / `data-wf-rich-text-schema` on the root span.
   - `safeHref` returns `#` for invalid URLs; valid URLs flow through.
3. **Editor controller component test** — `plugins/discourse-wireframe/test/javascripts/components/editor/inplace-text-controller-test.gjs`:
   - When service state is `(blockKey=…, argName=…)`, the controller finds the matching renderer span and mounts PM into it.
   - Typing emits `@change`; controller calls `updateBlockArg` with the result of `toStorage` (string when no marks, doc-JSON when marks present).
   - Bold via `Cmd+B`, italic via `Cmd+I`, link via toolbar — round-trip preserves marks.
   - Heading schema commits on Enter; paragraph schema inserts `hard_break`.
   - Escape exits, click outside exits.
4. **System spec** — `plugins/discourse-wireframe/spec/system/inline_text_editing_spec.rb`:
   - Open a layout with a heading + paragraph.
   - Click heading once (selects), click again (edits), type "Hello world", select "world", apply bold via toolbar, press Escape.
   - Verify `args.text` is a doc-JSON with the strong mark; canvas renders `Hello <strong>world</strong>`.
   - Inspector summary shows `Hello **world**`.
   - Edit again, remove the bold; verify `args.text` downgrades to the plain string `"Hello world"`.
   - Repeat for paragraph with multi-line (`hard_break`) content.
   - Confirm a layout with pre-existing `args.text: "Hello"` (string) loads, renders, and can be edited without migration.
5. **Undo integration spec** — `plugins/discourse-wireframe/spec/system/inline_text_editing_undo_spec.rb`:
   - In-session: while edit mode is active, Cmd+Z undoes the most recent keystroke (PM's internal undo); the canvas-level undo is not invoked.
   - Cross-session: edit heading from "Heading" → "Hello", commit; canvas Cmd+Z restores to "Heading"; Cmd+Shift+Z redoes to "Hello".
   - Mixed: structural change + inline edit + structural change — each undo step rewinds one logical action in the right order.
   - Revert path: pressing Escape on `stopEditing({ commit: false })` (if that path is exposed) restores the pre-edit snapshot without pushing an undo entry.
6. **Manual smoke** — load a homepage layout in dev, edit a heading inline, refresh, confirm it round-tripped. DevTools: confirm visitor (non-admin) view does not mount `prosemirror-view`.
7. **Lint** — `bin/lint --fix` on all changed/new JS/SCSS/Ruby files.

---

## Phase 2 — Multi-field adoption + Tab navigation

Once Phase 1 ships and the primitive is proven, the remaining text-bearing blocks adopt it. Each is ~5 lines of template change plus a one-line schema type bump. No new infrastructure beyond the Tab keymap.

**Modified — plugin:**
- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-media-card.gjs` — adopt for `name` (`plain`), `role` (`plain`), `badgeLabel` (`plain`), `title` (`paragraph`), `ctaLabel` (`plain`). Switch each arg's `type` to `"richInline"`.
- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-cta-banner.gjs` — `title` (`heading`), `content` (`paragraph`), `linkLabel` (`plain`).
- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-callout.gjs` — `body` (`paragraph`).
- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-button-link.gjs` — `label` (`plain`).
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inplace-text-controller.gjs` — add a `Tab` / `Shift+Tab` keymap to the PM editor: on Tab, find the next `[data-wf-rich-text-arg]` in DOM order within the same `[data-wf-block-id]`, call `startEditingArg` for it (which implicitly commits the current one). Shift+Tab walks backwards. If no next/previous exists in the current block, leave the keystroke alone (default browser behavior).

**Example adoption (wf-media-card):**

```gjs
<template>
  <div class="wf-media-card">
    <Image @src={{@avatarUrl}} />
    <div class="wf-media-card__content">
      <InlineRichTextRenderer @arg="name"       @schema="plain"     @value={{@name}} />
      <InlineRichTextRenderer @arg="role"       @schema="plain"     @value={{@role}} />
      <InlineRichTextRenderer @arg="badgeLabel" @schema="plain"     @value={{@badgeLabel}} />
      <h4>
        <InlineRichTextRenderer @arg="title"    @schema="paragraph" @value={{@title}} />
      </h4>
      <a href={{@ctaHref}}>
        <InlineRichTextRenderer @arg="ctaLabel" @schema="plain"     @value={{@ctaLabel}} />
      </a>
    </div>
  </div>
</template>
```

**Verification:**
1. **Multi-field system spec** — `plugins/discourse-wireframe/spec/system/inline_text_editing_multi_field_spec.rb`:
   - Open a layout with a `wf-media-card`.
   - Select the card, click the title region → edit mode active for `title`.
   - Without clicking outside, click the `name` region → edit mode switches to `name` (no flicker, no exit-then-re-enter).
   - Type in `name`, press Escape → exits cleanly; `args.name` updated.
   - Confirm the inspector reflects each arg's new value.
2. **Tab nav spec** — same file or adjacent:
   - In edit mode on `name`, press Tab → edit mode moves to `role`; cursor visible in `role`.
   - Continue Tab → `badgeLabel` → `title` → `ctaLabel`. Tab from the last field stays put (or exits — TBD; pick one and test).
   - Shift+Tab walks backward.
   - Type then Tab → previous field's value persists (one undo entry per session, even when chained by Tab).
3. **Lint** — `bin/lint --fix` on changed files.

---

## Phase 3 — Block-level editing flow (Enter → new block, arrow-key nav)

Brings the editor in line with Notion / Discourse-composer conventions for paragraph-flow editing. The wireframe's existing `_recordStructural` mechanism wraps these layout mutations into single undo entries automatically.

### Enter → new paragraph block (with Backspace merge)

In a `paragraph`-schema editor, change Enter from `hard_break` to **split the current paragraph block into two**. Shift+Enter retains the `hard_break` behavior.

- **On Enter:** intercept the PM keymap. Compute the cursor offset in the doc; split `entry.args.text` into a `before` doc and an `after` doc (PM has helpers for this). Mutate the layout: replace the current entry's `args.text` with `before`; insert a new sibling `wf:paragraph` entry immediately after with `args.text = after`. Move edit focus to the new entry, place the PM cursor at position 0. Wrap the whole mutation in `_recordStructural` so it's one undo entry.
- **On Backspace at position 0:** if the previous sibling in the layout is a `wf:paragraph`, merge: concatenate previous's `text` doc with the current's, replace previous's `args.text` with the merged doc, remove the current entry, move edit focus to previous with cursor placed at the join point. Also wrapped in `_recordStructural`.
- **Edge cases:** Enter in a `heading` schema continues to commit + exit (no split). Enter at the *end* of a paragraph creates a new empty paragraph below and focuses it (most common authoring gesture). Enter at the *start* moves the current content into a new paragraph below and leaves an empty one above — same outcome via the split path.

### Cross-block arrow-key navigation

- **Up at top row** of the current PM editor → exit edit mode; find the previous text-bearing block in layout order; enter edit mode on its first `richInline` arg; place the PM cursor at the end-of-last-line at the cursor's current visual column (best-effort).
- **Down at bottom row** → same direction, next text-bearing block.
- **Left at position 0** → previous block, cursor at end.
- **Right at end of doc** → next block, cursor at start.
- "Top row" / "bottom row" detection uses PM's `endOfTextblock` checks (it has helpers for `up` / `down` / `left` / `right` boundary detection).

**Modified — plugin:**
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inplace-text-controller.gjs` — extend the PM keymap with Enter / Backspace / arrow handlers as above. Each handler calls into the service for the layout mutation, then re-focuses the editor on the destination block.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/services/wireframe.js` — new methods: `splitInlineEditAt(cursorPos)`, `mergeInlineEditWithPrevious()`, `enterEditFromNeighbor({ direction, blockKey, cursorHint })`. All wrap layout mutations in `_recordStructural`.
- `plugins/discourse-wireframe/admin/assets/javascripts/discourse/lib/mutate-layout.js` — small helpers for "find previous/next text-bearing sibling in layout order" if not already present.

**Verification:**
1. **Enter-split system spec** — `plugins/discourse-wireframe/spec/system/inline_text_editing_block_flow_spec.rb`:
   - Edit a paragraph with content "Hello world", place cursor between "Hello " and "world", press Enter.
   - Verify two `wf:paragraph` blocks exist: first with "Hello ", second with "world"; cursor visible in second block at position 0.
   - Continue typing — appends to the new paragraph.
   - Press Cmd+Z — both blocks merge back into one with "Hello world", cursor restored at split point.
2. **Backspace-merge** — same file:
   - Two paragraphs "Hello" and "world", cursor at start of "world", press Backspace.
   - One paragraph "Helloworld", cursor at position 5 (the join).
   - Cmd+Z restores the two paragraphs.
3. **Shift+Enter still inserts hard_break** in a paragraph; Enter in a heading commits + exits.
4. **Arrow-key nav** — same file:
   - Three stacked blocks (heading, paragraph, paragraph). Edit middle paragraph at end of line. Press Down → edit moves to bottom paragraph, cursor at start (or visual-column match).
   - Press Up twice → edits move via paragraph then to heading, cursor at end-of-line.
   - Left at position 0 → previous block, cursor at end of doc.
5. **Lint** — `bin/lint --fix` on changed files.

---

## Deferred (post-Phase 3)

Real features the design supports but doesn't require for the experience to be useful. Track separately.

- **Slash menu** — `/` while editing opens a block-insertion menu (heading, image, list, etc.). Separate feature; can build on the Phase 3 split mechanism.
- **Editable inspector control** — first cut of `rich-inline` in the inspector is a read-only summary. A fallback editable text field would help headless / no-canvas editing scenarios.
- **Registry-based block arg type system** — `registerBlockArgType("richInline", { validate, default })` instead of editing core's frozen list. Only worth doing if a second consumer of the block system appears; `richInline` stays first-class in core in the meantime.
