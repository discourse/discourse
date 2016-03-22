
<!---

This README is automatically generated from the comments in these files:
paper-fab.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-fab.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-fab)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-fab)_


##&lt;paper-fab&gt;

Material design: [Floating Action Button](https://www.google.com/design/spec/components/buttons-floating-action-button.html)

`paper-fab` is a floating action button. It contains an image placed in the center and
comes in two sizes: regular size and a smaller size by applying the attribute `mini`. When
the user touches the button, a ripple effect emanates from the center of the button.

You may import `iron-icons` to use with this element, or provide a URL to a custom icon.
See `iron-iconset` for more information about how to use a custom icon set.

Example:

```html
<link href="path/to/iron-icons/iron-icons.html" rel="import">

<paper-fab icon="add"></paper-fab>
<paper-fab mini icon="favorite"></paper-fab>
<paper-fab src="star.png"></paper-fab>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-fab-background` | The background color of the button | `--accent-color` |
| `--paper-fab-keyboard-focus-background` | The background color of the button when focused | `--paper-pink-900` |
| `--paper-fab-disabled-background` | The background color of the button when it's disabled | `--paper-grey-300` |
| `--paper-fab-disabled-text` | The text color of the button when it's disabled | `--paper-grey-500` |
| `--paper-fab` | Mixin applied to the button | `{}` |
| `--paper-fab-mini` | Mixin applied to a mini button | `{}` |
| `--paper-fab-disabled` | Mixin applied to a disabled button | `{}` |
| `--paper-fab-iron-icon` | Mixin applied to the iron-icon within the button | `{}` |


