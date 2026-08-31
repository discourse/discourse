---
title: Designing for Different Devices (Touch & Hover)
short_title: Designing for Devices
id: designing-for-devices
---

This document outlines the APIs used to adapt Discourse's user interface for different devices.

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

These techniques are now considered deprecated and should be replaced with the [viewport and capability-based strategies](29-designing-for-responsive-widths.md) discussed in the next document. For backwards-compatibility, legacy desktop/mobile CSS is used when the viewport is larger/smaller than the `sm` threshold.

## See also

- [Designing for Responsive Widths](29-designing-for-responsive-widths.md) — breakpoints, viewport size, and container queries.
- [Guidelines for CSS classes using BEM](26-css-guidelines-bem.md) — CSS class naming conventions.
