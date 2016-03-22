
<!---

This README is automatically generated from the comments in these files:
paper-toolbar.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build Status](https://travis-ci.org/PolymerElements/paper-toolbar.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-toolbar)

_[Demo and API Docs](https://elements.polymer-project.org/elements/paper-toolbar)_


##&lt;paper-toolbar&gt;

Material design: [Toolbars](https://www.google.com/design/spec/components/toolbars.html)

`paper-toolbar` is a horizontal bar containing items that can be used for
label, navigation, search and actions.  The items placed inside the
`paper-toolbar` are projected into a `class="horizontal center layout"` container inside of
`paper-toolbar`'s Shadow DOM.  You can use flex attributes to control the items'
sizing.

Example:

```html
<paper-toolbar>
  <paper-icon-button icon="menu" on-tap="menuAction"></paper-icon-button>
  <div class="title">Title</div>
  <paper-icon-button icon="more-vert" on-tap="moreAction"></paper-icon-button>
</paper-toolbar>
```

`paper-toolbar` has a standard height, but can made be taller by setting `tall`
class on the `paper-toolbar`. This will make the toolbar 3x the normal height.

```html
<paper-toolbar class="tall">
  <paper-icon-button icon="menu"></paper-icon-button>
</paper-toolbar>
```

Apply `medium-tall` class to make the toolbar medium tall.  This will make the
toolbar 2x the normal height.

```html
<paper-toolbar class="medium-tall">
  <paper-icon-button icon="menu"></paper-icon-button>
</paper-toolbar>
```

When `tall`, items can pin to either the top (default), middle or bottom.  Use
`middle` class for middle content and `bottom` class for bottom content.

```html
<paper-toolbar class="tall">
  <paper-icon-button icon="menu"></paper-icon-button>
  <div class="middle title">Middle Title</div>
  <div class="bottom title">Bottom Title</div>
</paper-toolbar>
```

For `medium-tall` toolbar, the middle and bottom contents overlap and are
pinned to the bottom.  But `middleJustify` and `bottomJustify` attributes are
still honored separately.

To make an element completely fit at the bottom of the toolbar, use `fit` along
with `bottom`.

```html
<paper-toolbar class="tall">
  <div id="progressBar" class="bottom fit"></div>
</paper-toolbar>
```

When inside a `paper-header-panel` element, the class `.animate` is toggled to animate
the height change in the toolbar.

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-toolbar-title` | Mixin applied to the title of the toolbar | `{}` |
| `--paper-toolbar-background` | Toolbar background color | `--primary-color` |
| `--paper-toolbar-color` | Toolbar foreground color | `--primary-text-color` |
| `--paper-toolbar-height` | Custom height for toolbar | `64px` |
| `--paper-toolbar-sm-height` | Custom height for small screen toolbar | `56px` |
| `--paper-toolbar` | Mixin applied to the toolbar | `{}` |
| `--paper-toolbar-content` | Mixin applied to the content section of the toolbar | `{}` |
| `--paper-toolbar-medium` | Mixin applied to medium height toolbar | `{}` |
| `--paper-toolbar-tall` | Mixin applied to tall height toolbar | `{}` |
| `--paper-toolbar-transition` | Transition applied to the `.animate` class | `height 0.18s ease-in` |

### Accessibility

`<paper-toolbar>` has `role="toolbar"` by default. Any elements with the class `title` will
be used as the label of the toolbar via `aria-labelledby`.


