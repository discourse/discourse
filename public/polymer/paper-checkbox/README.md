
<!---

This README is automatically generated from the comments in these files:
paper-checkbox.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-checkbox.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-checkbox)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-checkbox)_


##&lt;paper-checkbox&gt;

Material design: [Checkbox](https://www.google.com/design/spec/components/selection-controls.html#selection-controls-checkbox)

`paper-checkbox` is a button that can be either checked or unchecked.  User
can tap the checkbox to check or uncheck it.  Usually you use checkboxes
to allow user to select multiple options from a set.  If you have a single
ON/OFF option, avoid using a single checkbox and use `paper-toggle-button`
instead.

Example:

```html
<paper-checkbox>label</paper-checkbox>

<paper-checkbox checked> label</paper-checkbox>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-checkbox-unchecked-background-color` | Checkbox background color when the input is not checked | `transparent` |
| `--paper-checkbox-unchecked-color` | Checkbox border color when the input is not checked | `--primary-text-color` |
| `--paper-checkbox-unchecked-ink-color` | Selected/focus ripple color when the input is not checked | `--primary-text-color` |
| `--paper-checkbox-checked-color` | Checkbox color when the input is checked | `--primary-color` |
| `--paper-checkbox-checked-ink-color` | Selected/focus ripple color when the input is checked | `--primary-color` |
| `--paper-checkbox-checkmark-color` | Checkmark color | `white` |
| `--paper-checkbox-label-color` | Label color | `--primary-text-color` |
| `--paper-checkbox-label-spacing` | Spacing between the label and the checkbox | `8px` |
| `--paper-checkbox-error-color` | Checkbox color when invalid | `--error-color` |
| `--paper-checkbox-size` | Size of the checkbox | `18px` |

This element applies the mixin `--paper-font-common-base` but does not import `paper-styles/typography.html`.
In order to apply the `Roboto` font to this element, make sure you've imported `paper-styles/typography.html`.


