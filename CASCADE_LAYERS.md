# CSS Cascade Layers in Discourse

Discourse now supports CSS Cascade Layers (`@layer`) for better stylesheet organization and specificity management.

## Layer Hierarchy

Layers are defined in priority order (lowest → highest specificity):

```css
@layer discourse-reset,
       discourse-base,
       discourse-foundation,
       discourse-components,
       discourse-plugins,
       discourse-theme;
```

## Layer Purposes

### 1. `discourse-reset`
- Vendor resets (normalize.css, pikaday, etc.)
- Lowest specificity
- Foundation for all other styles

### 2. `discourse-base`
- Base HTML element styles (html, body, links, typography)
- Accessibility styles (WHCM)
- CSS custom properties in `:root`

### 3. `discourse-foundation`
- Foundation utilities and helper classes
- Layout helpers (.pull-left, .clearfix, etc.)
- Visibility utilities (.hide, .show, etc.)

### 4. `discourse-components`
- All Discourse UI component styles
- Form-kit, float-kit, select-kit, modals
- Topic lists, composer, editor, timeline
- Desktop and mobile specific component styles

### 5. `discourse-plugins`
- Plugin stylesheet overrides
- Automatically applied by the stylesheet compiler
- Sits between core components and themes

### 6. `discourse-theme`
- Theme stylesheet overrides
- Highest priority (except unlayered styles)
- Automatically applied by the stylesheet compiler

## Benefits for Theme Developers

### Before Cascade Layers
Themes needed highly specific selectors to override core styles:

```scss
// Old approach - high specificity required
.discourse-no-touch .d-header-icons .icon:hover > .d-icon {
  color: var(--my-color);
}

.discourse-no-touch .btn-default.sidebar-new-topic-button {
  background: var(--my-bg);
}
```

### With Cascade Layers
Simple selectors work because the theme layer has higher priority:

```scss
// New approach - simple selectors work!
.d-header-icons .icon:hover > .d-icon {
  color: var(--my-color);
}

.btn-default.sidebar-new-topic-button {
  background: var(--my-bg);
}
```

## Key Advantages

1. **Simpler Selectors**: No need for `.discourse-no-touch` or other context classes
2. **No !important**: Layer order determines cascade, not selector specificity
3. **Better Maintainability**: Cleaner, more readable theme code
4. **Future-proof**: Core can refactor without breaking themes
5. **Clear Separation**: Each layer has a distinct purpose

## How It Works

### Core Stylesheet Entry Points
Layer order is defined in core entry points:
- `/app/assets/stylesheets/common.scss` - Defines layer order and common imports
- `/app/assets/stylesheets/desktop.scss` - Desktop component layer
- `/app/assets/stylesheets/mobile.scss` - Mobile component layer

### Automatic Layer Wrapping
The stylesheet compiler (`lib/stylesheet/compiler.rb`) automatically wraps:
- Plugin styles in `@layer discourse-plugins { ... }`
- Theme styles in `@layer discourse-theme { ... }`

You don't need to manually add `@layer` directives in your theme!

## Creating Sub-layers in Themes

Themes can create their own nested layers for internal organization:

```scss
// Define sub-layers within your theme
@layer variables, components, utilities;

@layer variables {
  :root {
    --my-color: blue;
  }
}

@layer components {
  .my-component {
    color: var(--my-color);
  }
}

@layer utilities {
  .my-util {
    margin: 1em;
  }
}
```

The entire theme will still be in the `discourse-theme` layer, but you can organize internally.

## Browser Support

Cascade Layers are supported in all modern browsers:
- Chrome 99+
- Firefox 97+
- Safari 15.4+
- Edge 99+

For older browsers, styles will fall back to standard specificity rules (still works, just without layer benefits).

## Migration Guide for Theme Developers

1. **Review your selectors**: Look for overly specific chains
2. **Simplify**: Remove unnecessary parent selectors and context classes
3. **Test thoroughly**: Verify styles still apply correctly
4. **No breaking changes**: Existing themes continue to work without modification

## Example: Horizon Theme

The Horizon theme has been updated to demonstrate cascade layers. Key changes:

**Before:**
```scss
.discourse-no-touch .d-header-icons .icon:hover,
.discourse-no-touch .d-header-icons .icon:focus {
  background-color: transparent;
}
```

**After:**
```scss
.d-header-icons .icon:hover,
.d-header-icons .icon:focus {
  background-color: transparent;
}
```

See `/themes/horizon/` for complete examples.

## Technical Details

### Implementation Files
- `app/assets/stylesheets/common.scss` - Layer definition
- `app/assets/stylesheets/desktop.scss` - Desktop layers
- `app/assets/stylesheets/mobile.scss` - Mobile layers
- `lib/stylesheet/compiler.rb` - Automatic layer wrapping for themes/plugins

### SCSS Variables and Mixins
SCSS variables and mixins are **not** placed inside layers because they need to be available globally during compilation. Only actual CSS rules go inside layers.

### Color Definitions
Color scheme stylesheets are compiled separately and remain outside the layer system (they define CSS custom properties in `:root`).

## Debugging Layers

Use browser DevTools to inspect layer order:

```css
/* In browser console */
document.styleSheets[0].cssRules
```

Or use the Layers panel in Chrome DevTools (in the Styles pane).

## Resources

- [MDN: @layer](https://developer.mozilla.org/en-US/docs/Web/CSS/@layer)
- [CSS Cascade Layers Specification](https://www.w3.org/TR/css-cascade-5/#layering)
- [A Complete Guide to CSS Cascade Layers](https://css-tricks.com/css-cascade-layers/)

---

**Last Updated**: October 31, 2025
