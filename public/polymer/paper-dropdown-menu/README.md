
<!---

This README is automatically generated from the comments in these files:
paper-dropdown-menu.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build Status](https://travis-ci.org/PolymerElements/paper-dropdown-menu.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-dropdown-menu)

_[Demo and API Docs](https://elements.polymer-project.org/elements/paper-dropdown-menu)_


##&lt;paper-dropdown-menu&gt;

Material design: [Dropdown menus](https://www.google.com/design/spec/components/buttons.html#buttons-dropdown-buttons)

`paper-dropdown-menu` is similar to a native browser select element.
`paper-dropdown-menu` works with selectable content. The currently selected
item is displayed in the control. If no item is selected, the `label` is
displayed instead.

The child element with the class `dropdown-content` will be used as the dropdown
menu. It could be a `paper-menu` or element that triggers `iron-select` when
selecting its children.

Example:

```html
<paper-dropdown-menu label="Your favourite pastry">
  <paper-menu class="dropdown-content">
    <paper-item>Croissant</paper-item>
    <paper-item>Donut</paper-item>
    <paper-item>Financier</paper-item>
    <paper-item>Madeleine</paper-item>
  </paper-menu>
</paper-dropdown-menu>
```

This example renders a dropdown menu with 4 options.

Similarly to using `iron-select`, `iron-deselect` events will cause the
current selection of the `paper-dropdown-menu` to be cleared.

### Styling

The following custom properties and mixins are also available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-dropdown-menu` | A mixin that is applied to the element host | `{}` |
| `--paper-dropdown-menu-disabled` | A mixin that is applied to the element host when disabled | `{}` |
| `--paper-dropdown-menu-ripple` | A mixin that is applied to the internal ripple | `{}` |
| `--paper-dropdown-menu-button` | A mixin that is applied to the internal menu button | `{}` |
| `--paper-dropdown-menu-input` | A mixin that is applied to the internal paper input | `{}` |
| `--paper-dropdown-menu-icon` | A mixin that is applied to the internal icon | `{}` |

You can also use any of the `paper-input-container` and `paper-menu-button`
style mixins and custom properties to style the internal input and menu button
respectively.


