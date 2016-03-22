
<!---

This README is automatically generated from the comments in these files:
paper-header-panel.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-header-panel.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-header-panel)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-header-panel)_


##&lt;paper-header-panel&gt;

`paper-header-panel` contains a header section and a content panel section.

__Important:__ The `paper-header-panel` will not display if its parent does not have a height.

Using layout classes, you can make the `paper-header-panel` fill the screen

```html
<body class="fullbleed layout vertical">
  <paper-header-panel class="flex">
    <paper-toolbar>
      <div>Hello World!</div>
    </paper-toolbar>
  </paper-header-panel>
</body>
```

Special support is provided for scrolling modes when one uses a paper-toolbar or equivalent for the
header section.

Example:

```html
<paper-header-panel>
  <paper-toolbar>Header</paper-toolbar>
  <div>Content goes here...</div>
</paper-header-panel>
```

If you want to use other than `paper-toolbar` for the header, add `paper-header` class to that
element.

Example:

```html
<paper-header-panel>
  <div class="paper-header">Header</div>
  <div>Content goes here...</div>
</paper-header-panel>
```

To have the content fit to the main area, use the `fit` class.

```html
<paper-header-panel>
  <div class="paper-header">standard</div>
  <div class="fit">content fits 100% below the header</div>
</paper-header-panel>
```

### Modes

Controls header and scrolling behavior. Options are `standard`, `seamed`, `waterfall`, `waterfall-tall`, `scroll` and
`cover`. Default is `standard`.

| Mode | Description |
| --- | --- |
| `standard` | The header is a step above the panel. The header will consume the panel at the point of entry, preventing it from passing through to the opposite side. |
| `seamed` | The header is presented as seamed with the panel. |
| `waterfall` | Similar to standard mode, but header is initially presented as seamed with panel, but then separates to form the step. |
| `waterfall-tall` | The header is initially taller (`tall` class is added to the header). As the user scrolls, the header separates (forming an edge) while condensing (`tall` class is removed from the header). |
| `scroll` | The header keeps its seam with the panel, and is pushed off screen. |
| `cover` | The panel covers the whole `paper-header-panel` including the header. This allows user to style the panel in such a way that the panel is partially covering the header. |

Example:

```html
<paper-header-panel mode="waterfall">
  <div class="paper-header">standard</div>
  <div class="content fit">content fits 100% below the header</div>
</paper-header-panel>
```

### Styling

To change the shadow that shows up underneath the header:

```css
paper-header-panel {
  --paper-header-panel-shadow: {
      height: 6px;
      bottom: -6px;
      box-shadow: inset 0px 5px 6px -3px rgba(0, 0, 0, 0.4);
  };
}
```

To change the panel container in different modes:

```css
paper-header-panel {
  --paper-header-panel-standard-container: {
    border: 1px solid gray;
  };

  --paper-header-panel-seamed-container: {
    border: 1px solid gray;
  };

  --paper-header-panel-waterfall-container: {
    border: 1px solid gray;
  };

  --paper-header-panel-waterfall-tall-container: {
    border: 1px solid gray;
  };

  --paper-header-panel-scroll-container: {
    border: 1px solid gray;
  };

  --paper-header-panel-cover-container: {
    border: 1px solid gray;
  };
}
```

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-header-panel` | Mixin applied to the element | `{}` |
| `--paper-header-panel-body` | Mixin applied to the element's body (i.e. everything below the toolbar) | `{}` |
| `--paper-header-panel-scroll-container` | Mixin applied to the container when in scroll mode | `{}` |
| `--paper-header-panel-cover-container` | Mixin applied to the container when in cover mode | `{}` |
| `--paper-header-panel-standard-container` | Mixin applied to the container when in standard mode | `{}` |
| `--paper-header-panel-seamed-container` | Mixin applied to the container when in seamed mode | `{}` |
| `--paper-header-panel-waterfall-container` | Mixin applied to the container when in waterfall mode | `{}` |
| `--paper-header-panel-waterfall-tall-container` | Mixin applied to the container when in tall waterfall mode | `{}` |


