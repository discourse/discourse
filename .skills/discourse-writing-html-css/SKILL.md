---
name: discourse-writing-html-css
description: Write and repair HTML/CSS/SCSS for Discourse core, plugins, themes, and theme components. Use when authoring or modifying templates (.gjs/.hbs), stylesheets (.scss), component markup, class names, responsive layout, FormKit/select-kit styling, or CSS regressions. Covers Discourse's BEM-with-standalone-modifiers naming, the CSS custom-property color palette (theming + dark mode), template/HTML conventions, CSS repair patterns, and where stylesheets live.
---

# Writing HTML & CSS for Discourse

Discourse styles must survive conditions the author never sees: a **theme** restyling the
component, **light/dark color schemes**, any **viewport** width, and **screen-reader** users
navigating the markup. A component is correct only when it holds up across all of them.

Two CSS rules are the most load-bearing — get them right by reflex:

1. **Name classes with BEM** so themes can target and override cleanly.
2. **Never hardcode color** — pull from the CSS custom-property palette so themes and dark
   mode work for free.

These rules operationalize Discourse's documented frontend philosophy — **mobile-first,
progressive enhancement (works without hover or JS), a themeable base layer, and a shared design
system over bespoke styling.** The two source-of-truth docs are
[`25-css-guidelines-bem.md`](../../docs/developer-guides/docs/03-code-internals/25-css-guidelines-bem.md)
(naming) and
[`27-designing-for-devices.md`](../../docs/developer-guides/docs/03-code-internals/27-designing-for-devices.md)
(responsive / device adaptation). The canonical real-world example is the chat loading skeleton —
[`plugins/chat/assets/javascripts/discourse/components/chat-skeleton.gjs`](../../plugins/chat/assets/javascripts/discourse/components/chat-skeleton.gjs)
and its `.scss`.

**Deeper detail lives in companion files — read the relevant one before working in that area:**

- [references/color-and-theming.md](references/color-and-theming.md) — full palette, semantic
  tokens, `--d-*` design vars.
- [references/layout-and-responsive.md](references/layout-and-responsive.md) — intrinsic layout
  and the `lib/viewport` breakpoint API.
- [references/css-authoring.md](references/css-authoring.md) — native-CSS-vs-SASS swaps, local
  custom properties (incl. theme interaction), shared mixins, file organization, and buttons.
- [references/css-repair.md](references/css-repair.md) — repairing existing CSS: stale selector
  deletion, selector scoping, overflow fixes, FormKit/token migration, mobile/desktop cleanup,
  and regression verification.
- [references/accessibility.md](references/accessibility.md) — screen-reader-only text, live-region
  announcements, contrast & forced-colors detail (the short a11y rules stay inline below).

## BEM naming (block / element / modifier)

Discourse uses a **modified BEM**: standard `block__element`, but modifiers are **standalone
classes**, not `block__element--modifier` suffixes.

| Part | Syntax | Example |
| --- | --- | --- |
| Block | `.block` | `.chat-skeleton`, `.d-button` |
| Element | `.block__element` | `.chat-skeleton__message`, `.header__item` |
| Modifier | `.--modifier` (standalone) | `.--cancel`, `.--animation`, `.--error` |
| State | `.is-foo` / `.has-foo` | `.is-open`, `.has-errors` |

- **One block per reusable component.** A distinct block-level class per Ember component, then
  hang elements and modifiers off it. Blocks may nest inside blocks.
- **An element** is a part with no meaning outside its block. Elements do **not** chain
  (`block__el1__el2` is wrong — use `block__el2`); the skeleton uses flat `__message`,
  `__message-avatar`, `__message-text`.
- **A modifier** is a standalone `.--modifier` for appearance variants (not the verbose
  `block__element--modifier`) — they're often reused, and it keeps the DOM readable.
- **State prefixes** `is-`/`has-` mark a condition driven by JS or interaction (`is-open`,
  `has-errors`), as opposed to a design variant (`--cancel`).
- **Prefer adding a class over the CSS `:has()` selector.** If a component already knows its own
  state, express it with a class (`is-open`, a `--modifier`) rather than `:has()`, which can be
  costly (re-evaluated on DOM mutations; broad/nested selectors are worst). Reserve `:has()` for
  when you can't add a class — e.g. styling a parent off cooked/third-party markup — and scope it
  tightly.

### Dash convention

Use **two dashes**: `.--modifier`. This is the documented standard and dominates the codebase.
Legacy **single-dash** modifiers exist (`.-animation` in the chat-skeleton predates the
convention) — don't copy them in new code, and don't mass-rename existing ones unless that's
the task.

### Name by meaning, not appearance

Class names describe **what a thing is**, never **how it looks** — a presentational name
becomes a lie the moment a theme, redesign, or responsive reflow changes the appearance, and
you can't rename it without hunting down every override. Avoid:

- **Position** — `block-right` → `block__sidebar`, `block__actions`.
- **Color** — `warning-red` / `text-blue` → `block--warning`, `block__link`.
- **Size** — `box-300px`, `text-large` → `block__panel`, `--prominent`.

Same for modifiers: `.--danger` / `.--compact` (intent), not `.--red` / `.--narrow`
(appearance).

### Don't build class names from user input

Never interpolate a user-controlled value (group/category/tag name, username, custom field)
directly into a class — they collide with generic utility/state classes (a group named "hidden"
emits `class="hidden"` and silently inherits its rules, often `display: none`) and make
unpredictable selectors. Carry the value in a **data attribute** and target it with an attribute
selector:

```hbs
{{! BAD — a group named "hidden" becomes class="hidden" }}
<span class="group-badge {{@group.name}}">…</span>

{{! GOOD — namespaced in an attribute, can't collide }}
<span class="group-badge" data-group-name={{@group.name}}>…</span>
```

```scss
.group-badge[data-group-name="staff"] { color: var(--tertiary); }
```

If a class is genuinely required (an existing theme hook), **prefix it** (`group-#{name}`,
`category-#{slug}`) and prefer slugs over free-text. These values still need normal escaping
for safety — see the XSS note under HTML conventions.

### Nesting & modifier application

Nest elements under the block with SCSS `&`. A modifier can apply **directly** on an element
(`&.--modifier`) or **indirectly** from an ancestor (`.--modifier &`) — the latter keeps the
DOM clean when many children react to one condition (e.g. one `--error` on the block):

```scss
.composer {
  &__input {
    &.--disabled { … }      // <input class="composer__input --disabled">
    .--error & { border-color: var(--danger); }  // <div class="composer --error"> … </div>
  }
}
```

## Color & theming — never hardcode

**Do not write hex, `rgb()`, or named colors for UI surfaces, text, or borders.** Use the CSS
custom-property palette so the result adapts to every theme and color scheme:

```scss
// BAD — breaks theming and dark mode
.notice { color: #222; background: #fff; border: 1px solid #ddd; }

// GOOD — adapts to every theme and color scheme
.notice { color: var(--primary); background: var(--secondary); border: 1px solid var(--primary-low); }
```

**Do not author a separate dark-mode block.** The palette already inverts; if something looks
wrong in dark mode you picked the wrong palette variable, not the wrong color.

**Prefer the semantic `--token-color-*` tokens for standard UI** (text, surfaces, borders,
icons); reach into the raw palette for bespoke components a token doesn't cover. Most-used
palette vars: `--primary` (text/foreground, with `-low`…`-high` and `-100`…`-900` steps),
`--secondary` (background), `--tertiary` (accent/links), `--danger`/`--success`, and
`rgba(var(--x-rgb), …)` for translucency. Full palette, tokens, and `--d-*` design vars:
[references/color-and-theming.md](references/color-and-theming.md).

**Don't rely on color alone, and mind contrast.** Never signal state or meaning by color by
itself (a red border for an error, a green dot for "online") — pair it with an icon, text, or
shape so it's perceivable to colorblind users and in forced-colors mode. Stick to the palette's
intended foreground/background pairings (text in `--primary` on a `--secondary` surface, etc.),
which are contrast-tuned per scheme; don't invent low-contrast combinations like `--primary-low`
text on `--secondary`. WCAG AA targets and forced-colors/WHCM notes:
[references/accessibility.md](references/accessibility.md).

## Style with restraint

Discourse is a highly themeable platform: core and plugin styles are a **base that theme
authors build on**, and anything you over-style is something they then have to override or
undo. Aim for the minimum that makes a component clear and functional, and leave the aesthetics
to themes.

- **Style for structure and function, not decoration.** Layout, spacing, sizing, and states
  (hover/focus/disabled) — yes. Decorative flourishes that aren't core to the component's
  meaning (drop shadows, gradients, custom borders, bespoke typography) are opinions a theme may
  not share — leave them out.
- **When a visual choice isn't load-bearing, it probably belongs in a theme, not core.** A
  plainer component a theme can dress up beats a heavily-styled one a theme must strip down. When
  in doubt, do less.
- It's the *why* behind several rules here — palette/tokens over fixed values, low specificity,
  override hooks (`...attributes`, local `--custom-properties`) — so themes can adjust without
  fighting your CSS.

## Browser support

Discourse targets the **latest stable releases** of Edge, Chrome, Firefox, and Safari
(including iOS 16.4+) — no IE, no legacy polyfills. Use modern CSS freely; the practical floor
is the oldest still-"latest-stable" Safari, so for a very new feature confirm Safari support
(Baseline "widely available" is a safe bar).

## Native CSS first

Discourse is gradually moving toward native CSS — when a native feature does the job, prefer it
over a compile-time SASS construct (`var(--…)` over `$variables`, `clamp()` over `sass:math`,
`light-dark()` over SCSS color functions, `var(--font-up-2)` over the `$font-up-2` alias).
**But keep the established helpers** — `z("header")`, the `lib/viewport` mixins, `&` nesting.
Full swap list + rule-of-thumb: [references/css-authoring.md](references/css-authoring.md).

## CSS best practices

- **Keep specificity low.** Target by **one class**, not deep descendant chains
  (`.card__title`, not `.card .body h2`). Don't style by ID or over-qualify (`div.card` →
  `.card`). **Avoid `!important`** — it usually signals a specificity fight you can solve by
  simplifying the selector. When it's genuinely necessary (overriding inline styles or a
  third-party rule), always add a comment saying why.

- **Units & flexible sizing.** Prefer `em`/`rem` over `px` so the UI scales with the user's
  adjustable base font size (`px` is fine for hairline borders). Avoid fixed heights/magic
  dimensions — let content size the box (translated strings and long usernames run longer than
  English); prefer `min-`/`max-` over hard `height`/`width`. Use **`gap`** for flex/grid spacing,
  not per-child margins. On user-generated text (titles, usernames, URLs), add
  `overflow-wrap: anywhere` so a long unbroken string can't force horizontal scroll.

- **Local custom properties.** Hoist a value to a component-scoped `--property` when it's reused
  or feeds a `calc()` (the name documents the math better than a magic number). Don't promote
  every value reflexively. Full pattern + theme interaction:
  [references/css-authoring.md](references/css-authoring.md).

- **Right-to-left: use logical properties.** Write `margin-inline`, `padding-inline`,
  `inset-inline-start`/`-end`, `border-start-*`, `text-align: start`/`end` — not `left`/`right`
  or `margin-left`. New code defaults to these and avoids a separate `_rtl.scss`. Legacy code
  uses physical props + `_rtl.scss`; don't mass-convert, but don't add new physical-direction
  rules either.

- **Motion & focus (a11y).** Gate non-essential animation behind
  `@media (prefers-reduced-motion: no-preference)` (the chat-skeleton shimmer does this). Animate
  **cheap properties** — `transform` and `opacity` are GPU-composited; animating layout
  properties (`width`, `height`, `top`/`left`, `margin`) triggers reflow and causes jank. Never
  `outline: none` without a replacement — use **`:focus-visible`** so keyboard users get a clear
  ring while it stays hidden for mouse clicks.

- **Reuse the shared mixins** (`common/foundation/mixins.scss`): `ellipsis` / `line-clamp($n)`
  for truncation, `d-animation` (bakes in reduced-motion), `unselectable`. Details and the
  legacy ones to skip: [references/css-authoring.md](references/css-authoring.md).

## Repairing existing CSS

When modifying existing Discourse CSS, prefer **removing or narrowing** over adding another
override. Most CSS regressions come from stale selectors, broad shared rules, old mobile/desktop
splits, or component architecture changing underneath a stylesheet.

Before writing new CSS, check where the selector is used and whether it is still rendered:

```sh
rg "<class-or-selector>" app/assets/stylesheets plugins themes
git log --oneline --since='2026-01-01' -- '*.scss' '*.css' --grep='fix|scope|selector|overflow|mobile|formkit|token|foundation|remove'
git show --stat --patch <suspect-commit> -- '*.scss' '*.css'
```

### Preferred repair moves

- **Scope broad selectors down.** Do not fix leakage by adding `!important` or deeper descendant
  chains. If `.name`, `.num`, `.btn`, `.d-icon`, `.select-kit`, `td`, or `th` leaks, target the
  real component/state: `.selected-name .name`, `.topic-list-data.num`,
  `.sidebar-filter__clear`.

- **Delete stale CSS and imports.** If a component/class was removed or replaced, remove its
  stylesheet/imports rather than keeping compatibility ghosts. Check with `rg` before assuming a
  selector still matters.

- **Move device-specific rules into `common/` with viewport mixins.** New and repaired styles
  should live in one responsive stylesheet using `@include viewport.from(...)` /
  `@include viewport.until(...)`, not split `desktop/` and `mobile/` copies.

- **Fix overflow with containment primitives.** Try `min-width: 0`, `minmax(0, 1fr)`,
  `max-width: 100%`, `max-height: 100%`, `overflow: hidden`, `flex-wrap: wrap`,
  `table-layout: fixed`, and `@include ellipsis` before adding magic widths.

- **Put scroll on the owning container, not `html`/`body`.** Especially on iOS, body scrolling
  fixes usually create flicker or broken fixed layouts. Identify the route/modal/panel that
  should scroll and give that container the height/overflow.

- **Use FormKit/select-kit APIs and tokens instead of global internal overrides.** Prefer
  FormKit field/container modifiers and `--form-kit-*` variables. Avoid broad rules like
  `.form-kit__container-content { width: 100%; }` outside FormKit itself.

- **Avoid global DOM inference.** Be suspicious of `body:has(...)`, `html { overflow-y: scroll; }`,
  `li:last-child` for dynamic lists, and component-only variables placed in `:root`. If the app
  knows the state, render a class/state/modifier.

- **Audit shared foundation changes.** Changes to `.btn`, `.select-kit`, `.d-icon`,
  `.topic-list-data`, category/tag badges, inputs, or foundation variables affect plugins and
  themes. Check chat, reactions, solved, topic voting, Data Explorer, admin, Horizon, mobile,
  and RTL where relevant.

### Red flags

Stop and re-check if your patch adds:

```scss
!important
body:has(...)
html { overflow-y: scroll; }
:root { --one-component-var: ... }
width: 340px;
min-width: 300px;
left: ...; right: ...; // without RTL thought
li:last-child
.name { ... }
.num { ... }
.btn { ... }
```

These are not banned, but they are radioactive enough to need a clear reason.

### Verification for CSS repair PRs

Check the affected surface in:

- desktop and mobile viewports
- light and dark palettes
- Horizon if header/sidebar/foundation/theme variables are touched
- RTL if physical positioning, icons, scroll fades, or nav is touched
- iOS Safari / iOS-like behavior for scroll/chat/composer fixes
- FormKit/select-kit contexts when forms or choosers are touched
- plugin surfaces sharing common foundation classes
- stale imports after deleting CSS

For visual UX changes, include before/after screenshots. Deep-dive repair patterns and examples:
[references/css-repair.md](references/css-repair.md).

## HTML / template conventions

Discourse templates are **`.gjs`** (Glimmer components with inline `<template>`) or `.hbs`.

- **Escape by default.** Use `{{value}}` (escaped). Never `{{{value}}}` / triple-curlies or raw
  `innerHTML` for user-derived content — that's an XSS hole. Trusted HTML must be explicitly
  marked (`trustHTML` / `htmlSafe`) and only for content you control.
- **Icons** come from the `dIcon` helper, never inline SVG or `<i class="fa">`:

  ```gjs
  import dIcon from "discourse/ui-kit/helpers/d-icon";
  // …in <template>: {{dIcon "chevron-left"}}
  ```

  Use a **real icon name** — icons render from Discourse's registered SVG sprite (a subset of
  Font Awesome), not arbitrary names. Don't guess; if a plugin needs an icon outside the subset,
  register it (`register_svg_icon` in `plugin.rb`).

- **Icon-only controls need an accessible label.** An icon conveys nothing to a screen reader,
  so a control with only an icon must carry a label: on `<DButton>` use `@title` (an i18n key —
  also a tooltip) or `@ariaLabel`, or `@translatedTitle` for pre-translated text; on raw markup,
  a translated `aria-label`. A button with visible text doesn't need this. (`dIcon` renders the
  glyph `aria-hidden` by default — the accessible name belongs on the control, not the icon.)
- **Screen-reader-only text uses `.sr-only`, not `display: none`.** For text that should exist
  for assistive tech but not show on screen (a label for an icon-only region, a skip target), use
  the `.sr-only` helper — `display: none`/`visibility: hidden` remove it from the accessibility
  tree. See [references/accessibility.md](references/accessibility.md).
- **Announce dynamic content via the `a11y` service — never a hand-rolled `aria-live`.** Content
  that appears without a page navigation (async results, a toast, inline validation) needs
  `this.a11y.announce(message, "polite" | "assertive")` to be read out. Live regions only work
  when **persistent in the DOM before the change** — which is exactly why you route through the
  service rather than adding an `aria-live` element alongside the new content. Details and the
  why: [references/accessibility.md](references/accessibility.md).
- **All display strings are translatable.** Pull copy through `i18n(...)`; never hardcode
  user-facing English. Use placeholders for interpolation — never concatenate translated
  fragments. Write strings in **"Sentence case"**.
- **Semantic, accessible markup.** Reach for the element that describes the content before a
  generic `<div>`/`<span>`:
  - **Landmarks & sectioning** — `<nav>`, `<header>`/`<footer>`, `<main>`, `<aside>`,
    `<section>`/`<article>` expose landmarks and an outline screen-reader users navigate by; a
    wall of `<div>`s gives them nothing to jump between. `<ul>`/`<ol>` + `<li>` for lists,
    `<table>` only for tabular data.
  - **Interactive & form** — real `<button>` for actions (not a clickable `<div>`), `<a>` for
    navigation, `<label>` tied to its input, `<fieldset>`/`<legend>` for groups.
  - Add `alt`/`aria-*` only to fill gaps native semantics can't — don't paper over a wrong
    element with ARIA. And don't add `<section>`/`<nav>` purely as styling hooks where they
    carry no role; a `<div>` is honest there.
  - Prefer existing `<DButton>` and other shared components — they get semantics and a11y right.
- **Buttons: `<button>` for actions, `<a>` for navigation — then one standalone variant.** Choose
  the element by behavior (anything that changes the URL is a link), not looks. A button-looking
  control needs `.btn` **plus exactly one** mutually-exclusive variant (`btn-default`,
  `btn-primary`, `btn-danger`, `btn-flat`/`btn-transparent`); `<DButton>` adds `.btn` for you, so
  pass the variant via `@class`. **Only controls that look *and* function like a standard button
  get these classes** — a `<button>` inside a dropdown, menu, tab, or list row is styled by its
  own component and must not get a `.btn-*` variant. Full guidance:
  [references/css-authoring.md](references/css-authoring.md).
- **Use FormKit for forms — don't roll your own.** Build forms with the `<Form>` component
  (`import Form from "discourse/components/form"`), which yields field/row/submit pieces
  (`<form.Field>`, `<form.Row>`, `<form.Submit>`) and handles layout, validation, state, and the
  label/error/a11y wiring for you. Don't hand-assemble a raw `<form>` with manual `<input>`s and
  bespoke validation. See
  [`docs/developer-guides/docs/03-code-internals/21-form-kit.md`](../../docs/developer-guides/docs/03-code-internals/21-form-kit.md)
  (`frontend/discourse/app/form-kit`).
- **Splat `...attributes` on the component's root element** so a caller can pass a class,
  `data-*`, `aria-*`, or a `--modifier` through. Without it the component is a closed box. The
  root is also where the BEM block class lives: `<div class="user-card" ...attributes>`.
- **Use `dConcatClass` for conditional/computed classes** instead of hand-built strings or
  stacked inline `{{if}}`s (`import dConcatClass from "discourse/ui-kit/helpers/d-concat-class"`).
  It drops falsy values cleanly:

  ```gjs
  <div class={{dConcatClass "card" (if @selected "is-selected") (if @compact "--compact")}}>
  ```

- **Know `<PluginOutlet>`, but don't add outlets speculatively.** Outlets are named seams where
  plugins/themes inject content (400+ across the app); you'll work inside them often. Each one is
  a **public API surface and maintenance commitment** — once it exists, extensions depend on its
  name and `@outletArgs`, so it can't be moved freely. Add one only for a concrete need; pass
  data via `lazyHash` (not `hash`) and name it by location (`above-…`, `below-…`). See
  [`13-plugin-outlet-connectors.md`](../../docs/developer-guides/docs/03-code-internals/13-plugin-outlet-connectors.md).
- **Heading levels follow the document outline, not type size.** Never pick a level for its
  default font size — if the right heading looks wrong-sized, style it in CSS
  (`font-size: var(--font-up-1)`). An `<h1>` styled smaller is fine; an `<h3>` chosen because
  you wanted smaller text is not.
- **Avoid "div-itis" — if you can't name what a wrapper does, drop it.** The test for every
  wrapping element: state its layout or semantic job in a few words (its own `max-width`, a
  positioning context, a scroll area, a flex/grid container, a real semantic region). If you
  can't, delete it and let the child stand on its own. A lone `<button>` wrapped in a `<div>`, or
  two or three nested `<div>`s that just pass content straight through, are the usual offenders —
  the markup carries weight it doesn't earn. Pick the right element too (`<span>` inline, `<div>`
  for a block/structural container, a semantic element where one fits). Beyond clutter, a stray
  wrapper between a flex/grid parent and its children **breaks layout** — the items stop being
  direct children, so `gap`/`flex`/`grid-template` no longer reach them. No style, role, or layout
  reason → delete it.
- **Components clean up after themselves — don't render empty containers.** If a container's
  contents are conditional, put the container inside the condition so it isn't emitted when
  empty — an empty-but-present element still counts as a flex/grid item and `gap` slot, leaving
  a phantom gap:

  ```hbs
  {{! GOOD — nothing emitted when there's nothing to show }}
  {{#if @actions}}
    <div class="card__actions">
      {{#each @actions as |action|}}<DButton @action={{action}} />{{/each}}
    </div>
  {{/if}}
  ```

  Likewise, **don't put `padding`/`margin`/`gap` on a container that can render empty** — that
  reserves space with no content. And **don't lean on `:empty`** to hide it: Ember leaves
  whitespace/comment nodes (`<!---->`) that make `:empty` fail to match, so it silently won't
  apply. The template conditional is the only reliable guard.
- **No empty backing class** for a template-only component unless explicitly requested.
- Don't add JSDoc to new code; if editing code that already has it, keep it accurate.

## Where stylesheets live

Core stylesheets are under `app/assets/stylesheets/`. Place a partial by target, then register
it in the matching `_index.scss` / parent `@import` (partials are underscore-prefixed and
**not** auto-globbed).

| Path | Applies to |
| --- | --- |
| `common/base/` | **Where new styles go** — one responsive stylesheet for all viewports |
| `common/components/` | Reusable component styles |
| `desktop/` | **Legacy desktop-only** — don't add new styles here |
| `mobile/` | **Legacy mobile-only** — don't add new styles here |
| `*_rtl.scss` | Legacy RTL overrides — new code uses logical properties instead |

- **Write one responsive stylesheet, not desktop + mobile copies.** Discourse designs
  **mobile-first** and enhances upward (see the philosophy doc,
  [`27-designing-for-devices.md`](../../docs/developer-guides/docs/03-code-internals/27-designing-for-devices.md)):
  new styles live in `common/` and adapt with breakpoints. **Prefer intrinsic layout** (e.g.
  `grid-template-columns: repeat(auto-fill, minmax(14em, 1fr))`) and reach for a breakpoint only
  to *restructure*; use the `lib/viewport` mixins (`viewport.from`/`until`/`between`). The legacy
  device split — the `desktop/`/`mobile/` dirs, the `.mobile-view`/`.desktop-view` classes, and
  `site.mobileView` in JS — is **deprecated**; don't use it. Details, breakpoints, and the
  `capabilities` service: [references/layout-and-responsive.md](references/layout-and-responsive.md).
- **Design to work without hover.** Touch users can't hover, so hover is an *enhancement*, not a
  requirement — nothing essential should be hover-only. When you do add hover styling, scope it
  to `html.discourse-no-touch` (see the layout reference).
- `common/foundation/variables.scss` and `mixins.scss` are injected everywhere — that's where
  layout-width vars and `z()` come from. (Font sizes/line-heights are native custom properties —
  `var(--font-up-2)`, `var(--line-height-medium)`.)

### Plugins & themes

- **Plugin** styles live in `plugins/<name>/assets/stylesheets/` and are registered in
  `plugin.rb`: `register_asset "stylesheets/common/my-feature.scss"` (optionally `, :desktop` /
  `, :admin`).
- **Themes/components** ship `common/`/`desktop/`/`mobile/` SCSS compiled with the palette
  injected — the same `var(--…)` and `$…` variables are available, so color, BEM, and native-CSS
  rules apply identically. The same responsive-first rule holds: put new styles in `common/`.

## Before committing

Lint every changed file (CSS via stylelint, templates via the JS toolchain):

```sh
bin/lint --fix path/to/file.scss path/to/file.gjs
bin/lint --fix --recent   # all recently changed files
```
