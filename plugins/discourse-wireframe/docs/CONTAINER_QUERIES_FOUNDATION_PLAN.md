# Container query foundation for `wf:layout`

Detailed execution plan for step 4 of `RESPONSIVE_AND_TOKENS_PLAN.md`: give `wf:layout` automatic adaptation to narrow widths via CSS container queries — zero author burden, no schema commitments, decoupled from later per-arg responsive overrides.

## Context

Today `wf:layout` renders a single layout regardless of available width:

- **Grid mode** at `columns: 6` stays 6-column even inside a 320px sidebar. Children overflow or scroll horizontally.
- **Row mode** stays horizontal at narrow widths. Children get squashed.
- **Stack mode** is already fine — it's the column case.

The only built-in responsive primitive is `viewport` conditions, which only hide/show entire blocks. There's no mechanism for the same blocks to *adapt* their layout.

`RESPONSIVE_AND_TOKENS_PLAN.md` proposes a three-layered approach: container queries → cascade breakpoints → per-arg overrides. This plan implements the first (cheapest, no schema commitment) layer.

### Why container queries (not media queries)

A layout inside an outlet's main column behaves differently from one in a narrow sidebar at the same viewport. Media queries can't distinguish those contexts; container queries respond to the *available width* regardless of viewport. Discourse core already uses them in some components (`group.scss`, `directory.scss`) — this isn't a new primitive for the codebase.

## Current state (verified from `wf-layout.gjs`)

The container `<div>` carries inline `style` produced by `containerStyle()` (lines 284-331):

```js
// Grid mode:
"display: grid; grid-template-columns: repeat(6, 1fr); grid-template-rows: repeat(2, minmax(80px, auto)); gap: 1rem; align-items: stretch; padding: ...; position: relative; transition: ...;"
```

```js
// Stack / row mode:
"display: flex; flex-direction: row; gap: 1rem; align-items: stretch;"
```

Each grid child gets a `.wf-layout__cell` wrapper with `cellStyle()` (lines 243-257):

```js
"grid-column: 3 / 5; grid-row: 1; display: grid; place-items: stretch stretch; min-width: 0; min-height: 0;"
```

### The blocker: inline style precedence

Container query rules in a stylesheet **cannot override an inline-style property** (inline always wins unless `!important`). The `grid-template-columns`, `flex-direction`, and per-cell `grid-column` declarations all sit in inline `style`.

The fix is to refactor `containerStyle()` and `cellStyle()` so the **author's intent is passed as CSS custom properties**, and the **stylesheet owns the actual layout properties**:

```js
// New inline style on the layout container (grid mode):
"--wf-layout-cols: repeat(6, 1fr); --wf-layout-rows: repeat(2, minmax(80px, auto)); --wf-layout-gap: 1rem; --wf-layout-align: stretch; padding: ...; position: relative;"
```

```scss
// In wireframe.scss:
.wf-layout--grid {
  display: grid;
  grid-template-columns: var(--wf-layout-cols, repeat(6, 1fr));
  grid-template-rows: var(--wf-layout-rows, repeat(2, minmax(80px, auto)));
  gap: var(--wf-layout-gap, 1rem);
  align-items: var(--wf-layout-align, stretch);
  transition: grid-template-columns 180ms ease, grid-template-rows 180ms ease, gap 180ms ease;
}

@container wf-layout (max-width: 40rem) {
  .wf-layout--grid {
    grid-template-columns: 1fr;  // overrides the base rule cleanly
  }
}
```

The inline custom property `--wf-layout-cols` is only consumed by the base rule's `var(...)` lookup. The `@container` rule sets `grid-template-columns` directly, bypassing the custom-property — so it wins by cascade order, no `!important` needed.

Same pattern for `cellStyle()` — children's `grid-column` / `grid-row` move to custom properties.

## Approach

### A. Refactor `containerStyle()` to custom-property hand-off

`wf-layout.gjs` lines 284-331 → emit only custom-property setters:

```js
get containerStyle() {
  const mode = this.resolvedMode;
  const gap = this.args.gap ?? 1;
  const align = this.args.align ?? "stretch";

  if (mode === "grid") {
    const columns = this.args.columns ?? 6;
    const rows = this.args.rows ?? 2;
    const columnTemplate = (this.args.columnTemplate ?? "").trim();
    const rowTemplate = (this.args.rowTemplate ?? "").trim();
    const rowHeight = (this.args.rowHeight ?? "minmax(80px, auto)").trim() || "minmax(80px, auto)";
    const cols = columnTemplate.length > 0 ? columnTemplate : `repeat(${columns}, 1fr)`;
    const rowsTpl = rowTemplate.length > 0 ? rowTemplate : `repeat(${rows}, ${rowHeight})`;
    return trustHTML(
      `--wf-layout-cols: ${cols}; ` +
        `--wf-layout-rows: ${rowsTpl}; ` +
        `--wf-layout-gap: ${gap}rem; ` +
        `--wf-layout-align: ${align};`
    );
  }
  // stack / row:
  return trustHTML(
    `--wf-layout-gap: ${gap}rem; --wf-layout-align: ${align};`
  );
}
```

Move `display: grid`, `display: flex`, `flex-direction`, `padding`, `position: relative`, and the `transition` rule into the stylesheet against `.wf-layout--grid` / `.wf-layout--row` / `.wf-layout--stack` selectors.

### B. Refactor `cellStyle()` similarly

`wf-layout.gjs` lines 243-257:

```js
cellStyle = (containerArgs) => {
  if (this.resolvedMode !== "grid") return null;
  const grid = containerArgs?.grid ?? {};
  return trustHTML(
    `--wf-cell-column: ${grid.column ?? "auto"}; ` +
      `--wf-cell-row: ${grid.row ?? "auto"}; ` +
      `--wf-cell-align: ${grid.align ?? "stretch"}; ` +
      `--wf-cell-justify: ${grid.justify ?? "stretch"};`
  );
};
```

Stylesheet owns the actual properties:

```scss
.wf-layout--grid > .wf-layout__cell {
  grid-column: var(--wf-cell-column, auto);
  grid-row: var(--wf-cell-row, auto);
  display: grid;
  place-items: var(--wf-cell-align, stretch) var(--wf-cell-justify, stretch);
  min-width: 0;
  min-height: 0;
}
```

### C. Establish the container query context

Add to `.wf-layout`:

```scss
.wf-layout {
  container-type: inline-size;
  container-name: wf-layout;
}
```

### D. Define the collapse rules

Single breakpoint at `40rem` (matches core's `sm` from `viewport.scss`). Below it:

```scss
@container wf-layout (max-width: 40rem) {
  .wf-layout--grid {
    grid-template-columns: 1fr;
    grid-template-rows: auto;  // single column; let rows auto-flow
  }
  .wf-layout--grid > .wf-layout__cell {
    grid-column: 1 / -1;
    grid-row: auto;
  }
  .wf-layout--row {
    flex-direction: column;
  }
}
```

Stack mode needs no rule — it's already column-oriented.

### E. Editor-mode considerations

The grid overlay (`grid-overlay.gjs` line 624) reads tracks via `getComputedStyle()`. When the container query collapses the grid to 1 column, `getComputedStyle` returns the collapsed tracks (1 column wide). The overlay's cell-positioning math therefore works correctly *automatically* — it sees a 1-column grid and renders 1 placeholder per row.

**Open question / acceptable wart for v1**: when an author has placed a child at `column: 3 / 5` and the grid collapses to 1 column, the CSS rule above forces it to `1 / -1` (full width). The child still renders; the explicit placement is ignored at narrow widths. This is the *desired* fallback (per the plan's "container queries as the default" framing) but might confuse authors testing in the editor with the simulation toolbar narrowed to mobile. **Mitigation**: keep the explicit `column / row` editing UI showing the author's *desktop* value regardless of simulated viewport, and add a small badge on the inspector ("auto-collapses below 40rem") so the behaviour is visible.

This badge can ship after the foundation lands; the foundation itself doesn't need it to be correct.

### F. What stays on inline `style`

The editor-only `padding: var(--wireframe-container-margin)` and `position: relative` for grid mode → move to a CSS rule scoped to `.wf-layout--grid` (no reason to keep them inline). The CSS variable resolves to empty on the live page (it's defined in the editor's chrome scope), so the rule is a no-op outside the editor.

```scss
.wf-layout--grid {
  position: relative;
  padding: var(--wireframe-container-margin, 0);
}
```

## Files to modify

- `plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-layout.gjs`
  - `containerStyle` getter (lines 284-331) → custom-property hand-off
  - `cellStyle` arrow fn (lines 243-257) → custom-property hand-off
- `plugins/discourse-wireframe/assets/stylesheets/wireframe.scss`
  - New `.wf-layout`, `.wf-layout--grid`, `.wf-layout--row`, `.wf-layout--stack` rules with `container-type` / layout properties / transitions
  - New `@container wf-layout` block with collapse rules
  - New `.wf-layout--grid > .wf-layout__cell` rule

No JS modifier or component changes outside `wf-layout.gjs` itself. The grid overlay needs no edits (it reads computed styles, which already reflect the collapsed state).

## Implementation steps (ordered)

1. **Add the stylesheet rules first** (with no behavioural change). Define `.wf-layout--grid` / `.wf-layout--row` / `.wf-layout--stack` reading from custom properties with sensible defaults. Don't add `@container` rules yet. Verify the existing live page renders identically (the inline styles still win at this stage, so visually nothing changes; this is a defence-in-depth step).
2. **Switch `containerStyle()` to custom-property hand-off**. Now the stylesheet rules take over. Verify the live page and editor render identically to before.
3. **Switch `cellStyle()` to custom-property hand-off**. Same verification.
4. **Add `container-type: inline-size; container-name: wf-layout` to `.wf-layout`.** Still no behavioural change.
5. **Add the `@container wf-layout (max-width: 40rem)` block** with the collapse rules. NOW the layout adapts at narrow widths.
6. **Test in the editor at simulated mobile width**; verify grid overlay still computes correct cell rectangles (it should, via `getComputedStyle`).
7. **Test on the live page** by narrowing the browser; verify both standalone layouts and layouts inside a sidebar collapse correctly (container query, not viewport).

Each step is independently revertable. The first three are pure refactors (no observable change), giving us safe checkpoints before introducing actual responsive behaviour in step 5.

## Edge cases

- **Nested layouts.** A `wf:layout` inside another `wf:layout`'s child slot also has `container-name: wf-layout`. The inner query matches the *innermost* containing element with that name — so the inner layout reads its own width, not the outer's. Correct behaviour by spec; just worth noting.
- **`columnTemplate` overrides.** Authors who supplied a custom `columnTemplate: "1fr 2fr 1fr"` still get the collapse to `1fr` at narrow widths. Acceptable — single-column is always the safe collapse.
- **`free-grid` mode.** `resolvedMode` normalises `free-grid` → `grid`, so the rules apply.
- **Layouts inside grids.** A nested layout inside a grid cell receives its own container width (the cell's width). Container queries trigger appropriately based on the cell's actual rendered width.
- **Layouts that are narrow at desktop already.** A 3-column layout that's only 30rem wide gets collapsed too — which is the right call (3 columns in 30rem are cramped). If the author *wants* to preserve narrow multi-column layouts, that's the opt-out arg from the parent plan (out of scope here).
- **CSS transitions during collapse.** The base rule includes `transition: grid-template-columns 180ms ease, ...`. Container-query-driven changes go through the transition, so the collapse animates instead of popping. Free win.

## Verification

Run after each implementation step:

1. `bin/lint --fix plugins/discourse-wireframe/assets/javascripts/discourse/blocks/wf-layout.gjs plugins/discourse-wireframe/assets/stylesheets/wireframe.scss`
2. `bin/qunit plugins/discourse-wireframe/test/javascripts/unit/lib/mutate-layout-test.gjs` — existing unit tests green.
3. Live page (after step 5):
   - Place a 4-column `wf:layout` with four children at outlet root. Narrow the browser to < 640px. Expect grid → 1 column, each child full-width.
   - Same layout inside a sidebar block outlet. Sidebar at ~280px while viewport is wide → grid collapses inside the sidebar too. The same outlet on the main column at 1200px width → grid stays 4-column. Confirms it's container-driven, not viewport-driven.
4. Editor canvas (after step 5):
   - Enter the editor on a page with a 4-column grid. Use the simulation toolbar to switch to "Mobile". Canvas narrows; grid collapses to 1 column; cell drop targets re-render to match the 1-column reality.
   - Drag a palette block over the collapsed grid — drop indicator targets the visible single-column cells.
   - Switch back to "Desktop" — grid restores to 4 columns; cell placements honoured again.
5. Row-mode layout:
   - `wf:layout` mode=row with three children in an outlet. Narrow → flex-direction: column. Children stack.

## Risks & rollback

- **Risk**: an existing site theme has CSS overrides that target `.wf-layout` with their own `grid-template-columns`. Those overrides would now win regardless of inline style (since we moved away from inline). **Mitigation**: low likelihood for a feature this new; we control the only published consumer.
- **Risk**: the custom-property fallback chain has a typo and a layout's `grid-template-columns` resolves to the literal string `var(--wf-layout-cols, ...)` because the custom property isn't set. **Mitigation**: each step is independently testable; defaults inside `var(...)` mean the base rule still renders something sensible even without the custom property.
- **Risk**: the grid overlay's track reads break because the collapsed grid has different track count than the saved `columns` arg. **Mitigation**: the overlay reads from `getComputedStyle`, which always reflects the *rendered* grid — it doesn't care what the saved arg says. Verified by code reading; bench-tested in step 6.

**Rollback**: each step is one commit. Reverting the last commit (the `@container` block) restores pre-responsive behaviour without touching the custom-property refactor. Reverting all five restores the original inline-style approach.

## What this lands

Authors don't see a new UI. The editor's chrome and palette are unchanged. The only observable difference: layouts that previously overflowed at narrow widths now collapse gracefully — on the live page, in sidebar outlets, in narrow canvas simulations.

This is the foundation other responsive work (per-arg overrides, breakpoint switcher, etc.) builds on, but it's valuable as a standalone shipped feature.

## Out of scope (deferred to later phases)

- `mobileCollapse: "auto" | "preserve" | "stack-each"` opt-out arg — wait for an author who explicitly needs the opt-out.
- Per-arg responsive overrides (`responsive: true` on schema, breakpoint cascade in inspector).
- Toolbar promotion of the simulation switcher to "edit-at-breakpoint" mode.
- Auto-adjustment of `gap` at narrow widths (could shrink from 1rem to 0.5rem under `sm` — easy add, but defer until requested).
- Multiple breakpoint stops (e.g. 2 columns at tablet, 1 column at mobile) — current plan ships the single `sm` collapse; intermediates can be added by extending the `@container` block.
