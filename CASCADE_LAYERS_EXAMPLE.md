# Cascade Layers Implementation Example

This document shows how the cascade layer implementation works in practice.

## Compiled CSS Structure

When Discourse compiles stylesheets, the output will have this structure:

### Core Stylesheet (common.css)

```css
/* Layer order definition - establishes priority */
@layer discourse-reset,
       discourse-base,
       discourse-foundation,
       discourse-components,
       discourse-plugins,
       discourse-theme;

/* Font variables (outside layers - preprocessor only) */
/* ... font imports ... */

/* Layer 1: Reset */
@layer discourse-reset {
  /* normalize.css */
  html { line-height: 1.15; }
  body { margin: 0; }
  /* ... more reset styles ... */
}

/* Layer 2: Base */
@layer discourse-base {
  :root {
    --space: 0.25rem;
    --d-border-radius: 4px;
    /* ... CSS custom properties ... */
  }

  html {
    color: var(--primary);
    font-family: var(--font-family);
    background-color: var(--secondary);
  }

  a, a:visited, a:hover {
    color: var(--d-link-color);
    text-decoration: none;
  }
  /* ... more base element styles ... */
}

/* Layer 3: Foundation */
@layer discourse-foundation {
  .pull-left { float: left; }
  .pull-right { float: right; }
  .hide { display: none !important; }
  .clearfix::after { clear: both; }
  /* ... utility classes ... */
}

/* Layer 4: Components */
@layer discourse-components {
  /* Form Kit */
  .form-kit__container { /* ... */ }

  /* Select Kit */
  .select-kit .select-kit-header { /* ... */ }

  /* Header */
  .d-header {
    box-shadow: 0 1px 3px rgba(0,0,0,0.12);
    background: white;
  }

  .d-header-icons .icon:hover {
    background-color: rgba(0,0,0,0.05);
  }

  /* Buttons */
  .btn-default {
    background: #f0f0f0;
    color: #333;
  }

  .btn-default:hover {
    background: #e0e0e0;
  }

  /* ... thousands more component styles ... */
}

/* Layers 5 & 6 added dynamically per theme */
```

### Plugin Stylesheet (my-plugin.css)

```css
/* Automatically wrapped by compiler */
@layer discourse-plugins {
  /* Plugin styles override core components */
  .my-plugin-widget {
    background: var(--tertiary);
  }

  /* Even simple selectors override complex core selectors! */
  .btn-default {
    /* This wins over .discourse-components .btn-default:hover
       because discourse-plugins layer > discourse-components layer */
    border-radius: 8px;
  }
}
```

### Theme Stylesheet (horizon-theme.css)

```css
/* Automatically wrapped by compiler */
@layer discourse-theme {
  /* Theme has highest priority */

  /* BEFORE cascade layers, you needed this: */
  /* .discourse-no-touch .d-header-icons .icon:hover { ... } */

  /* NOW, simple selector works! */
  .d-header-icons .icon:hover {
    background-color: transparent; /* Overrides core! */
  }

  /* BEFORE: .discourse-no-touch .btn-default.sidebar-new-topic-button */
  /* NOW: */
  .btn-default {
    background: var(--primary-100);
  }

  .btn-default:hover {
    box-shadow: 0 0 0 4px var(--button-box-shadow);
  }
}
```

## Specificity Comparison

### Example 1: Header Icon Hover

**Core Styles (discourse-components layer):**
```css
@layer discourse-components {
  /* Specificity: 0-3-1 (3 classes, 1 element) */
  .discourse-no-touch .d-header-icons .icon:hover > .d-icon {
    color: var(--primary-medium);
  }
}
```

**Theme Styles (discourse-theme layer):**
```css
@layer discourse-theme {
  /* Specificity: 0-3-1 (same!) but WINS because of layer order */
  .d-header-icons .icon:hover > .d-icon {
    color: var(--header_primary-medium);
  }

  /* Could even simplify to 0-2-0 and still win! */
  .d-icon {
    color: var(--header_primary-medium);
  }
}
```

### Example 2: Button Styles

**Core Styles (discourse-components layer):**
```css
@layer discourse-components {
  /* Specificity: 0-1-0 */
  .btn-default {
    background: #f0f0f0;
    color: #333;
  }

  /* Specificity: 0-2-0 */
  .btn-default:hover {
    background: #e0e0e0;
  }
}
```

**Old Theme Approach (no layers):**
```css
/* Had to increase specificity to override */
/* Specificity: 0-3-0 */
.discourse-no-touch .btn-default.sidebar-new-topic-button {
  background: var(--primary-100);
}

/* Specificity: 0-4-0 (!!) */
.discourse-no-touch .btn-default.sidebar-new-topic-button:hover {
  background: var(--primary-200);
}
```

**New Theme Approach (with layers):**
```css
@layer discourse-theme {
  /* Specificity: 0-1-0 (same as core, but wins via layer!) */
  .btn-default {
    background: var(--primary-100);
  }

  /* Specificity: 0-2-0 (simpler!) */
  .btn-default:hover {
    background: var(--primary-200);
  }
}
```

## Real-World Example: Horizon Theme

### Before (header.scss)
```scss
// High specificity required to override core
.discourse-no-touch .d-header-icons .icon:hover,
.discourse-no-touch .d-header-icons .icon:focus,
.header-sidebar-toggle button:focus:hover,
.discourse-no-touch .header-sidebar-toggle button:hover {
  background-color: transparent;
}

.discourse-no-touch .d-header-icons .icon:hover > .d-icon,
.drop-down-mode .d-header-icons .active .icon > .d-icon,
.drop-down-mode .d-header-icons .header-color-scheme-toggle .-expanded > .d-icon,
.discourse-no-touch .header-sidebar-toggle button:hover .d-icon {
  color: var(--header_primary-medium);
}
```

### After (header.scss)
```scss
// Simplified - layer handles priority
.d-header-icons .icon:hover,
.d-header-icons .icon:focus,
.header-sidebar-toggle button:focus:hover,
.header-sidebar-toggle button:hover {
  background-color: transparent;
}

.d-header-icons .icon:hover > .d-icon,
.d-header-icons .active .icon > .d-icon,
.d-header-icons .header-color-scheme-toggle .-expanded > .d-icon,
.header-sidebar-toggle button:hover .d-icon {
  color: var(--header_primary-medium);
}
```

**Benefit:** Removed 5 instances of `.discourse-no-touch` and `.drop-down-mode` classes!

## How Layer Priority Works

```
┌─────────────────────────────────────────┐
│  Unlayered Styles (highest priority)    │  ← Emergency overrides only
├─────────────────────────────────────────┤
│  @layer discourse-theme { }             │  ← Theme styles
├─────────────────────────────────────────┤
│  @layer discourse-plugins { }           │  ← Plugin styles
├─────────────────────────────────────────┤
│  @layer discourse-components { }        │  ← Core components
├─────────────────────────────────────────┤
│  @layer discourse-foundation { }        │  ← Utilities
├─────────────────────────────────────────┤
│  @layer discourse-base { }              │  ← Base elements
├─────────────────────────────────────────┤
│  @layer discourse-reset { }             │  ← Resets (lowest priority)
└─────────────────────────────────────────┘
```

Within each layer, normal specificity rules apply. But styles in a higher layer always win over styles in a lower layer, regardless of specificity!

## Testing in Browser DevTools

### Chrome DevTools

1. Open DevTools (F12)
2. Go to Elements tab
3. In Styles pane, look for "Layers" section
4. You'll see layer names and order
5. Inspect any element to see which layer its styles come from

### Firefox DevTools

1. Open DevTools (F12)
2. Go to Inspector tab
3. Select an element
4. In Rules pane, you'll see `@layer layer-name` annotations
5. Styles show which layer they belong to

## Migration Checklist for Theme Developers

- [ ] Review theme selectors for unnecessary specificity
- [ ] Remove context classes like `.discourse-no-touch` (unless needed for functionality)
- [ ] Remove modifier classes like `.drop-down-mode` (unless needed for state)
- [ ] Test all theme styles in browser
- [ ] Verify hover/focus states work correctly
- [ ] Check mobile responsive styles
- [ ] Test with plugins enabled
- [ ] Document any layer-specific patterns in theme README

## Common Patterns

### Pattern 1: Simple Override
```scss
// Core (discourse-components)
.topic-list .topic-title {
  font-size: 1.5em;
  font-weight: bold;
}

// Theme (discourse-theme) - simple selector wins!
.topic-title {
  font-size: 1.8em;
}
```

### Pattern 2: State Override
```scss
// Core (discourse-components)
.btn-primary:hover:not([disabled]) {
  background: darkblue;
}

// Theme (discourse-theme) - simpler selector wins!
.btn-primary:hover {
  background: var(--accent-color);
}
```

### Pattern 3: Component Override
```scss
// Core (discourse-components)
.d-header .d-header-icons .icon .d-icon {
  color: currentColor;
}

// Theme (discourse-theme) - any matching selector wins!
.d-icon {
  color: var(--header_primary-medium);
}
```

---

**Implementation Date**: October 31, 2025
**Discourse Version**: Compatible with all versions supporting modern CSS
