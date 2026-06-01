# CSS authoring reference

Companion to the **Native CSS first** and **CSS best practices** sections of `SKILL.md`. The
rules live there; this file holds the full native-vs-SASS swap list, the local-custom-property
deep dive (including theme interaction), and the shared-mixin inventory.

## Native CSS vs. SASS — what to swap, what to keep

Discourse is gradually moving toward native CSS. When a native feature does the job, use it
instead of a SASS construct that only exists at compile time — reduce what the precompiler has to do.

**Don't introduce new SASS machinery** for something CSS now handles natively. Prefer:

- `var(--…)` custom properties over SCSS `$variables` for values that should be themeable or
  live at runtime.
- `clamp()` / `min()` / `max()` over SCSS math (`@use "sass:math"`, `math.div`).
- `light-dark()` and the palette over SCSS color functions (`color.adjust`, `color.scale`,
  `dark-light-diff`) for new color work.
- `rgb(var(--x-rgb) / 0.1)` or `rgba(var(--x-rgb), 0.1)` over SASS color manipulation.
- The **font-size scale** and **line-heights** as custom properties — `var(--font-up-2)`,
  `var(--font-0)`, `var(--font-down-1)`, `var(--line-height-medium)` (and `-rem` variants like
  `var(--font-up-2-rem)` for headings). The SCSS `$font-up-2` names are just compile-time
  aliases to these — use the `var(--…)` form directly.

**But keep using the established SASS helpers** where they're still the tool — don't reinvent
them in the name of "native":

- **`z("header")`** for z-index — always use the function, never raw z-index integers. It
  keeps the global stacking order coherent (`$z-layers` in `foundation/variables.scss`).
- The **`lib/viewport`** mixins (`viewport.from`/`until`/`between`) for responsive rules (see
  `references/layout-and-responsive.md`).
- Layout-width vars and other genuinely compile-time SCSS values.
- SCSS **`&` nesting** for BEM structure is fine and conventional.

**Rule of thumb:** new value that should be themeable/runtime → CSS custom property;
cross-cutting system already wrapped in a helper (z-index, breakpoints) → use the helper;
one-off compile-time math/color that native CSS can now express → native CSS.

## Local custom properties for repeated & computed values

Define a component-scoped custom property when a value earns it — it keeps the component DRY
and self-documenting. (These are local, component-level vars, distinct from the global
palette/token variables.)

**Reused within the component** — if the same value appears in more than one place, hoist it
to a `--property` on the block so there's a single source of truth:

```scss
.user-card {
  --avatar-size: 3em;

  &__avatar {
    width: var(--avatar-size);
    height: var(--avatar-size);
  }
  &__body {
    margin-inline-start: var(--avatar-size); // stays in sync automatically
  }
}
```

**Use custom properties as documentation inside `calc()`.** A named variable explains the math
far better than a magic number plus a comment:

```scss
// AVOID — magic number, comment is the only thing explaining it
width: calc(1em + 20px); // 20px = avatar margin

// PREFER — the name IS the documentation, and it can't drift from a stale comment
width: calc(1em + var(--avatar-margin));
```

**Override the variable at a breakpoint instead of redeclaring every rule — when it has
several consumers.** If a responsive change is "this value is smaller on mobile" and the value
feeds multiple declarations, retarget the single var and they all update together:

```scss
.user-card {
  --avatar-size: 3em;
  &__avatar { width: var(--avatar-size); height: var(--avatar-size); }
  &__body  { margin-inline-start: calc(var(--avatar-size) + 0.5em); }

  @include viewport.until(sm) {
    --avatar-size: 2em; // updates the avatar AND the body offset in one line
  }
}
```

But don't reach for this when a value is **used once** — overriding `--avatar-margin` to change
a single `margin` is more indirection than just redeclaring `margin`. Use the variable-override
pattern only when it saves repeating several dependent declarations (or recomputing a
`calc()`); otherwise redeclare the property directly.

### Theme interaction

Local custom properties are the more theme-friendly shape: a theme can retarget `--avatar-size`
once and every consumer (including breakpoint overrides) updates consistently, instead of
re-overriding each dependent rule. Two things to keep in mind:

- A theme's **unconditional** override (`.user-card { --avatar-size: 4em }`) loads after core at
  equal specificity, so it wins everywhere and flattens your responsive shrink. This isn't
  specific to variables — an unconditional redeclared property does the same — but it means a
  value you override at breakpoints is also a value a theme can fully take over.
- Don't promote every value to a variable reflexively; each one reads as a de-facto theming
  API. Reserve it for values with a real single-source-of-truth or override reason.

## Shared mixins (`common/foundation/mixins.scss`)

A handful of mixins encode patterns that are easy to get subtly wrong. Prefer them over
reinventing:

- **Text truncation** — `@include ellipsis;` for single-line truncation
  (`overflow`/`white-space`/`text-overflow`, the most-used helper in the codebase) and
  `@include line-clamp($lines);` for multi-line.
- **`@include d-animation($name, $duration, $easing);`** — runs an animation and automatically
  zeroes its duration under `prefers-reduced-motion`, so you get reduced-motion handling for
  free.
- **`@include unselectable;`** — disables text selection on UI chrome (buttons, labels, tab
  strips) where stray selection is annoying, especially on touch.

Skip the legacy ones: the `user-select` mixin is deprecated (write the native `user-select`
property — autoprefixer handles the rest), and `clearfix` is rarely needed once you're using
flex/grid.

For focus rings, prefer native `:focus-visible` (see `SKILL.md`). The `default-focus` mixin is
an optional shorthand for the standard ring's appearance — pair it inside `:focus-visible` if
you want the default look, but a hand-written `outline` is equally fine.
