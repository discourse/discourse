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
.feature-card {
  --card-gutter: 1.5em;

  &__header {
    padding-inline: var(--card-gutter);
  }
  &__body {
    padding-inline: var(--card-gutter); // stays in sync automatically
  }
}
```

**Use custom properties as documentation inside `calc()`.** A named variable explains the math
far better than a magic number plus a comment:

```scss
// AVOID — magic number, comment is the only thing explaining it
width: calc(100% - 48px); // 48px = gutter on both sides

// PREFER — the name IS the documentation, and it can't drift from a stale comment
width: calc(100% - var(--card-gutter) * 2);
```

**Override the variable at a breakpoint instead of redeclaring every rule — when it has
several consumers.** If a responsive change is "this value is smaller on mobile" and the value
feeds multiple declarations, retarget the single var and they all update together:

```scss
.feature-card {
  --card-gutter: 1.5em;
  &__header { padding-inline: var(--card-gutter); }
  &__body   { padding-inline: var(--card-gutter); }
  &__media  { margin-inline: calc(var(--card-gutter) * -1); } // bleed past the gutter

  @include viewport.until(sm) {
    --card-gutter: 1em; // updates header, body AND media bleed in one line
  }
}
```

But don't reach for this when a value is **used once** — overriding `--card-gutter` to change
a single `padding` is more indirection than just redeclaring `padding`. Use the variable-override
pattern only when it saves repeating several dependent declarations (or recomputing a
`calc()`); otherwise redeclare the property directly.

### Theme interaction

Local custom properties are the more theme-friendly shape: a theme can retarget `--card-gutter`
once and every consumer (including breakpoint overrides) updates consistently, instead of
re-overriding each dependent rule. Two things to keep in mind:

- A theme's **unconditional** override (`.feature-card { --card-gutter: 2em }`) loads after core at
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

## Don't re-declare what a base class already sets

Most components sit on top of a shared base class (`.btn`, `.d-modal`, `.form-kit__container`,
`.fk-d-menu`, `.select-kit`, etc.) that already establishes layout. Don't repeat those properties
on your component class — they add noise and drift out of sync when the base changes. Write only
what differs.

```scss
// AVOID — .btn is already `display: inline-flex; align-items: center`
.my-feature__button {
  display: flex;
  align-items: center;
  font-size: var(--font-up-1); // the only line that changes anything
}

// PREFER — keep only what differs from the base
.my-feature__button {
  font-size: var(--font-up-1);
}
```

Only redeclare a base property when you are deliberately overriding it (e.g. switching `flex` to
`grid`), and make that intent obvious from context.

## File organization

Two habits that keep a stylesheet easy to read and to repair later:

**One rule block per selector.** Within a file, a selector should appear once. Don't write the
same selector two or three times in the file — merge the declarations into a single block.
Repeated blocks fight over source order, hide each other, and make a regression hard to trace.

```scss
// AVOID — same selector declared twice in one file
.topic-map { display: flex; }
// ...other rules...
.topic-map { gap: var(--space-2); }

// PREFER — one block, BEM elements/modifiers nested with `&`
.topic-map {
  display: flex;
  gap: var(--space-2);

  &__title { }
  &.--collapsed { }
}
```

**Order rules to match the page.** Arrange selectors top-to-bottom in the order their elements
appear in the DOM — header before body before footer — so reading the stylesheet mirrors scanning
the rendered component.

```scss
.topic-map {
  &__header { }
  &__body { }
  &__stats { }
  &__footer { }
}
```

## Buttons

Buttons are one of the most commonly mis-classed elements. Get two things right: pick the element
by behavior, and apply exactly one standalone variant — and only to real buttons.

**`<button>` for actions, `<a>` for navigation.** This is a semantic/UX decision, independent of
how the element is styled: `<button>` for anything that causes an interaction on the current page
(toggle, submit, open a menu, run a command); `<a>` for anything that navigates elsewhere,
including changes that only update the URL (e.g. appending `?filter=something`). A link can be
styled to look like a button and vice-versa — choose the element by what it *does*, then style it.
Prefer `<DButton>` / a real `<a>` over a clickable `<div>`.

**`.btn` is the base.** `<DButton>` applies `.btn` automatically. `.btn` only handles structure
and positioning (`display: inline-flex`, centering, padding, `cursor`) — it is not a complete
visual style on its own. A normal button needs `.btn` **plus exactly one variant**.

**Pick exactly one variant, standalone.** The variants are **mutually exclusive — never combine
two** (no `btn-primary btn-flat`):

| Variant | Use for |
| --- | --- |
| `.btn-default` | The standard button. |
| `.btn-primary` | The call-to-action — generally only **one** per focused section. |
| `.btn-danger` | Destructive or hard-to-recover actions (delete, reset). |
| `.btn-flat` | A subtler button (e.g. header buttons). Used rarely.|
| `.btn-transparent` | The subtlest — visually close to a link but keeps button padding/alignment (e.g. composer top-right close/minimise/expand). |

(`.btn-success` and sizes `.btn-small` / `.btn-large` also exist; sizes compose with a variant.)
With `<DButton>`, pass the variant as a class:

```hbs
<DButton class="btn-primary" @label="topic.reply.title" @action={{this.reply}} />
```

**Colouring a `.btn-transparent` — use the modifiers, not a second variant.** A transparent button
that needs a colour takes a standalone `--primary`, `--danger`, or `--success` modifier. Don't
combine it with `btn-primary`/`btn-danger`/`btn-success` — that double-declaration is the old
approach and is deprecated (the suffixed classes linger only for safety).

```hbs
{{! AVOID — deprecated double declaration }}
<DButton class="btn-transparent btn-danger" @icon="trash-can" @action={{this.delete}} />

{{! PREFER — standalone colour modifier }}
<DButton class="btn-transparent --danger" @icon="trash-can" @action={{this.delete}} />
```

**`.btn-link` — a button that looks like a link.** Rare: when the element is genuinely an action
(so it must be a `<button>`, not an `<a>`) yet should look like a plain link. Use `@display="link"`
on `<DButton>`, which renders `.btn-link` **instead of** `.btn`. Don't add a `.btn-default`/etc.
variant on top of it.

```hbs
<DButton @display="link" @label="post.actions.defer" @action={{this.defer}} />
```

**Only "real" buttons get these classes.** The variant classes are only for controls that look
*and* function like a standard button. Plenty of controls are buttons semantically (a real
`<button>`) but are styled entirely by their surrounding component and must **not** receive any
`.btn-*` variant — an item in a dropdown/menu, a row in a list, a tab, a clickable card. Putting a
`.btn-*` class on these means fighting the component's own styling (you override more than you
keep, per "don't re-declare what a base class sets" above). Style them with their own component
class instead. Rule of thumb: looks and behaves like a standard button → `.btn` + one variant;
button behavior but styled like its container → its own class, **no** `.btn-*`.
