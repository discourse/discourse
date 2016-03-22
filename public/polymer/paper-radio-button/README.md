
<!---

This README is automatically generated from the comments in these files:
paper-radio-button.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-radio-button.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-radio-button)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-radio-button)_


##&lt;paper-radio-button&gt;

Material design: [Radio button](https://www.google.com/design/spec/components/selection-controls.html#selection-controls-radio-button)

`paper-radio-button` is a button that can be either checked or unchecked.
User can tap the radio button to check or uncheck it.

Use a `<paper-radio-group>` to group a set of radio buttons.  When radio buttons
are inside a radio group, exactly one radio button in the group can be checked
at any time.

Example:

```html
<paper-radio-button></paper-radio-button>
<paper-radio-button>Item label</paper-radio-button>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-radio-button-unchecked-background-color` | Radio button background color when the input is not checked | `transparent` |
| `--paper-radio-button-unchecked-color` | Radio button color when the input is not checked | `--primary-text-color` |
| `--paper-radio-button-unchecked-ink-color` | Selected/focus ripple color when the input is not checked | `--primary-text-color` |
| `--paper-radio-button-checked-color` | Radio button color when the input is checked | `--primary-color` |
| `--paper-radio-button-checked-ink-color` | Selected/focus ripple color when the input is checked | `--primary-color` |
| `--paper-radio-button-label-color` | Label color | `--primary-text-color` |
| `--paper-radio-button-label-spacing` | Spacing between the label and the button | `10px` |

This element applies the mixin `--paper-font-common-base` but does not import `paper-styles/typography.html`.
In order to apply the `Roboto` font to this element, make sure you've imported `paper-styles/typography.html`.


