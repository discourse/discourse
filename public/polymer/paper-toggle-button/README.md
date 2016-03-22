
<!---

This README is automatically generated from the comments in these files:
paper-toggle-button.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-toggle-button.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-toggle-button)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-toggle-button)_


##&lt;paper-toggle-button&gt;

Material design: [Switch](https://www.google.com/design/spec/components/selection-controls.html#selection-controls-switch)

`paper-toggle-button` provides a ON/OFF switch that user can toggle the state
by tapping or by dragging the switch.

Example:

```html
<paper-toggle-button></paper-toggle-button>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-toggle-button-unchecked-bar-color` | Slider color when the input is not checked | `#000000` |
| `--paper-toggle-button-unchecked-button-color` | Button color when the input is not checked | `--paper-grey-50` |
| `--paper-toggle-button-unchecked-ink-color` | Selected/focus ripple color when the input is not checked | `--dark-primary-color` |
| `--paper-toggle-button-checked-bar-color` | Slider button color when the input is checked | `--primary-color` |
| `--paper-toggle-button-checked-button-color` | Button color when the input is checked | `--primary-color` |
| `--paper-toggle-button-checked-ink-color` | Selected/focus ripple color when the input is checked | `--primary-color` |
| `--paper-toggle-button-unchecked-bar` | Mixin applied to the slider when the input is not checked | `{}` |
| `--paper-toggle-button-unchecked-button` | Mixin applied to the slider button when the input is not checked | `{}` |
| `--paper-toggle-button-checked-bar` | Mixin applied to the slider when the input is checked | `{}` |
| `--paper-toggle-button-checked-button` | Mixin applied to the slider button when the input is checked | `{}` |
| `--paper-toggle-button-label-color` | Label color | `--primary-text-color` |
| `--paper-toggle-button-label-spacing` | Spacing between the label and the button | `8px` |

This element applies the mixin `--paper-font-common-base` but does not import `paper-styles/typography.html`.
In order to apply the `Roboto` font to this element, make sure you've imported `paper-styles/typography.html`.


