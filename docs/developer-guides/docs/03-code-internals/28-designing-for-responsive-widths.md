---
title: Designing for Responsive Widths (Breakpoints, Viewport & Containers)
short_title: Designing for Responsive Widths
id: designing-for-responsive-widths
---

This document outlines the APIs used to adapt Discourse's user interface to different widths — both the browser viewport, and individual containers on the page.

We design "mobile first" and then add customizations for larger sizes as needed. The breakpoints we use are:

| Breakpoint | Size  | Pixels (at 16px body font size) |
| ---------- | ----- | ------------------------------- |
| xs         | 20rem | 320px                           |
| sm         | 40rem | 640px                           |
| md         | 48rem | 768px                           |
| lg         | 64rem | 1024px                          |
| xl         | 80rem | 1280px                          |
| 2xl        | 96rem | 1536px                          |

### Viewport Size

The most common way to use these breakpoints is based on the browser's viewport size. To use these in an SCSS file, add `@use "lib/viewport";` at the top of the file, then use one of the available mixins:

```scss
@use "lib/viewport";

@include viewport.from(lg) {
  // SCSS rules here will be applied to
  // devices larger than the lg breakpoint
}

@include viewport.until(sm) {
  // SCSS rules here will be applied to
  // devices smaller than the sm breakpoint
}

@include viewport.between(sm, md) {
  // SCSS rules here will be applied to
  // devices with a size between the sm
  // and md breakpoints
}
```

In general, SCSS is the recommended way to handle layout differences based on viewport size. For advanced cases, the same breakpoints can be accessed in Ember components via the capabilities service. For example:

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";

class MyComponent extends Component {
  @service capabilities;

  <template>
    {{#if this.capabilities.viewport.lg}}
      This text will be displayed for devices larger than the lg breakpoint
    {{/if}}

    {{#unless this.capabilities.viewport.sm}}
      This text will be displayed for devices smaller than the sm breakpoint
    {{/unless}}
  </template>
}
```

These properties are reactive, and Ember will automatically re-render the relevant parts of the template as the browser is resized.

For a real example, see `app/assets/stylesheets/common/base/directory.scss`, which uses `viewport.until(sm)`/`viewport.until(md)` throughout to adapt the user directory table's layout at narrower viewport widths.

### Container Queries

Sometimes a component's layout should respond to the size of its own container, rather than the size of the whole browser viewport — for example, a card that's rendered both full-width and inside a narrow sidebar. For these cases, use `lib/container`, which shares the same breakpoint scale and mixin API as `lib/viewport`.

Container queries only work against an ancestor element that has been explicitly opted in with `container-type`. Set that (and, optionally, a `container-name` if you need to target a specific ancestor) on the element whose size you want to query against:

```scss
.my-component {
  container-type: inline-size;
  container-name: my-component;
}
```

Then, add `@use "lib/container";` at the top of the file, and use the mixins the same way as `lib/viewport`:

```scss
@use "lib/container";

.my-component {
  container-type: inline-size;
  container-name: my-component;

  @include container.until(sm, my-component) {
    // SCSS rules here will be applied when
    // .my-component itself is narrower than
    // the sm breakpoint
  }
}
```

The `$name` argument is optional. Omit it if there's only one queryable container in scope; pass it when you need to target a specific named container (for example, if the rule lives on a descendant, rather than the container element itself).

For a real example, see `.db-whos-posting` in `app/assets/stylesheets/admin/dashboard/engagement.scss`, which sets `container-type: inline-size; container-name: db-whos-posting;` and uses `container.until(sm, db-whos-posting)` to adapt its own layout independently of the viewport.

## See also

- [Designing for Different Devices (Touch & Hover)](27-designing-for-devices.md) — detecting touch/hover capability, and legacy mobile/desktop modes.
- [Guidelines for CSS classes using BEM](25-css-guidelines-bem.md) — CSS class naming conventions.
