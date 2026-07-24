# Layout & responsive reference

Companion to the **Where stylesheets live** section of `SKILL.md`. The rules live there:
write one responsive stylesheet (not desktop/mobile copies), prefer intrinsic layout, and use
`lib/viewport` for breakpoints. This file is the detail.

The authoritative philosophy is
[`docs/developer-guides/docs/03-code-internals/27-designing-for-devices.md`](../../../docs/developer-guides/docs/03-code-internals/27-designing-for-devices.md):
**design mobile-first, then enhance for larger viewports and richer input** — read it for the
full picture.

## Prefer intrinsic layout over breakpoints

Reach for a breakpoint only when a layout genuinely needs to *restructure*. For sizing and
wrapping, prefer **intrinsic, self-adjusting CSS** that responds to available space on its
own — it adapts at every width, not just at the breakpoints you happened to pick, and it's
far less code to maintain.

```scss
// GOOD — one rule, fills and wraps columns to fit any container width
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(14em, 1fr));
  gap: 1em;
}

// AVOID — redefining the column count at each breakpoint
.card-grid {
  grid-template-columns: 1fr;
  @include viewport.from(sm) { grid-template-columns: repeat(2, 1fr); }
  @include viewport.from(lg) { grid-template-columns: repeat(3, 1fr); }
  @include viewport.from(xl) { grid-template-columns: repeat(4, 1fr); }
}
```

Other intrinsic tools to favor before media queries: `flex-wrap` with `flex` basis/grow,
`min()`/`max()`/`clamp()` for fluid sizing, `min-content`/`max-content`/`fit-content`, and
`auto-fit`/`auto-fill` + `minmax()`. Use `lib/viewport` breakpoints for the cases intrinsic
layout can't express — e.g. moving a sidebar from beside the content to below it, or swapping
`flex-direction`.

## Responsive breakpoints — `lib/viewport`

Make a component responsive with the standardized **`lib/viewport`** module rather than ad-hoc
media queries or the legacy `breakpoint()` mixin. `@use` it at the top of the file, then use
the `from` / `until` / `between` mixins:

```scss
@use "lib/viewport";

.my-component {
  flex-direction: column; // mobile-first default

  @include viewport.from(md) {
    flex-direction: row; // wider viewports
  }

  &__sidebar {
    @include viewport.until(lg) {
      display: none;
    }
  }
}
```

Standard breakpoints
([`app/assets/stylesheets/lib/viewport.scss`](../../../app/assets/stylesheets/lib/viewport.scss)):

| Name | Width |
| --- | --- |
| `sm` | 40rem |
| `md` | 48rem |
| `lg` | 64rem |
| `xl` | 80rem |
| `2xl` | 96rem |

- `viewport.from($bp)` → `width >= $bp` (min-width); `viewport.until($bp)` → `width < $bp`
  (max-width); `viewport.between($from, $until)` → a bounded range.
- Prefer a **mobile-first** default with `from()` to scale up. Always use a named breakpoint —
  never a raw `px`/`rem` media query — so breakpoints stay consistent sitewide.

For viewport-conditional rendering in a component (rather than CSS), use the `capabilities`
service — `this.capabilities.viewport.lg`, etc. — but SCSS is the recommended way to handle
layout differences.

## Touch & hover

Some devices have only a touchscreen, some only a pointer, some both — and touch users **cannot
hover**. So design interfaces to **work entirely without hover**, and add hover only as an
enhancement. When you do add hover styling, scope it to non-touch devices via the
`html.discourse-no-touch` class (Discourse adds `.discourse-touch` / `.discourse-no-touch` to
`<html>` based on `(any-pointer: coarse)`):

```scss
html.discourse-no-touch .my-component__reveal-on-hover {
  opacity: 0;
  &:hover { opacity: 1; }
}
```

In components, the same info is on the `capabilities` service (`this.capabilities.touch`).

## Legacy device modes (deprecated)

Discourse historically shipped separate mobile/desktop stylesheets and layouts switched by
user-agent. **All of these are deprecated** and being removed — don't use them in new code:

- the `desktop/` and `mobile/` stylesheet directories,
- the `.mobile-view` / `.desktop-view` HTML classes,
- the `site.mobileView` boolean in JS.

Replace them with the viewport breakpoints and `capabilities` service above. ("Mobile mode"
will become an alias for "viewport width &lt; `sm`" for backwards compatibility.)
