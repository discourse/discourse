---
title: Designing for Different Devices (Viewport Size, Touch/Hover, etc.)
short_title: Designing for Devices
id: designing-for-devices
---

This document outlines the APIs used to adapt Discourse's user interface for different devices.

### Viewport Size

The most important characteristic to consider is the viewport size. We design "mobile first" and then add customizations for larger devices as needed. The breakpoints we use are:

| Breakpoint | Size  | Pixels (at 16px body font size) |
| ---------- | ----- | ------------------------------- |
| sm         | 40rem | 640px                           |
| md         | 48rem | 768px                           |
| lg         | 64rem | 1024px                          |
| xl         | 80rem | 1280px                          |
| 2xl        | 96rem | 1536px                          |

To use these in an SCSS file, add `@use "lib/viewport";` at the top of the file, then use one of the available mixins:

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

### Touch & Hover

Some devices only have touchscreens, some only have a traditional mouse pointer, and some have both. Importantly, touchscreen users cannot "hover" over elements. Therefore, interfaces should be designed to work entirely without hover states, with hover-specific enhancements added for devices that support them.

There are several ways to detect touch/hover capability via CSS and JavaScript. For consistency, we recommend using Discourse's helpers instead of those CSS/JS APIs directly.

For CSS, you can target the `.discourse-touch` and `.discourse-no-touch` classes, which are added to the `<html>` element. These are determined based on the `(any-pointer: coarse)` media query.

For example:

```scss
html.discourse-touch {
  // SCSS rules here will apply to devices with a touch screen,
  // including mobiles/tablets and laptops/desktops with touch screens.
}

html.discourse-no-touch {
  // SCSS rules here will apply to devices with no touch screen.
}
```

This information is also available in Ember components via the capabilities service:

```gjs
import Component from "@glimmer/component";
import { service } from "@ember/service";

class MyComponent extends Component {
  @service capabilities;

  <template>
    {{#if this.capabilities.touch}}
      This text will be displayed for devices with a touch screen
    {{/if}}

    {{#unless this.capabilities.touch}}
      This text will be displayed for devices with no touch screen
    {{/unless}}
  </template>
}
```

### Legacy Mobile / Desktop Modes

Historically, Discourse shipped two completely different layouts and stylesheets for "mobile" and "desktop" views, based on the browser's user-agent. Developers would target these modes by putting CSS in specific mobile/desktop directories, by using the `.mobile-view`/`.desktop-view` HTML classes, and the `site.mobileView` boolean in JavaScript.

These techniques are now considered deprecated and should be replaced with the viewport and capability-based strategies discussed above. We will be removing the dedicated modes in the near future, making "mobile mode" an alias for "viewport width less than `sm`" for backwards compatibility.
