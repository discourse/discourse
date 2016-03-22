
<!---

This README is automatically generated from the comments in these files:
paper-tooltip.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-tooltip.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-tooltip)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-tooltip)_


##&lt;paper-tooltip&gt;

Material design: [Tooltips](https://www.google.com/design/spec/components/tooltips.html)

`<paper-tooltip>` is a label that appears on hover and focus when the user
hovers over an element with the cursor or with the keyboard. It will be centered
to an anchor element specified in the `for` attribute, or, if that doesn't exist,
centered to the parent node containing it.

Example:

```html
<div style="display:inline-block">
  <button>Click me!</button>
  <paper-tooltip>Tooltip text</paper-tooltip>
</div>

<div>
  <button id="btn">Click me!</button>
  <paper-tooltip for="btn">Tooltip text</paper-tooltip>
</div>
```

The tooltip can be positioned on the top|bottom|left|right of the anchor using
the `position` attribute. The default position is bottom.

```html
<paper-tooltip for="btn" position="left">Tooltip text</paper-tooltip>
<paper-tooltip for="btn" position="top">Tooltip text</paper-tooltip>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-tooltip-background` | The background color of the tooltip | `#616161` |
| `--paper-tooltip-opacity` | The opacity of the tooltip | `0.9` |
| `--paper-tooltip-text-color` | The text color of the tooltip | `white` |
| `--paper-tooltip` | Mixin applied to the tooltip | `{}` |


