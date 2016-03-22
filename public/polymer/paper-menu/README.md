
<!---

This README is automatically generated from the comments in these files:
paper-menu.html  paper-submenu.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build Status](https://travis-ci.org/PolymerElements/paper-menu.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-menu)

_[Demo and API Docs](https://elements.polymer-project.org/elements/paper-menu)_


##&lt;paper-menu&gt;

Material design: [Menus](https://www.google.com/design/spec/components/menus.html)

`<paper-menu>` implements an accessible menu control with Material Design styling. The focused item
is highlighted, and the selected item has bolded text.

```html
<paper-menu>
  <paper-item>Item 1</paper-item>
  <paper-item>Item 2</paper-item>
</paper-menu>
```

An initial selection can be specified with the `selected` attribute.

```html
<paper-menu selected="0">
  <paper-item>Item 1</paper-item>
  <paper-item>Item 2</paper-item>
</paper-menu>
```

Make a multi-select menu with the `multi` attribute. Items in a multi-select menu can be deselected,
and multiple items can be selected.

```html
<paper-menu multi>
  <paper-item>Item 1</paper-item>
  <paper-item>Item 2</paper-item>
</paper-menu>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-menu-background-color` | Menu background color | `--primary-background-color` |
| `--paper-menu-color` | Menu foreground color | `--primary-text-color` |
| `--paper-menu-disabled-color` | Foreground color for a disabled item | `--disabled-text-color` |
| `--paper-menu` | Mixin applied to the menu | `{}` |
| `--paper-menu-selected-item` | Mixin applied to the selected item | `{}` |
| `--paper-menu-focused-item` | Mixin applied to the focused item | `{}` |
| `--paper-menu-focused-item-after` | Mixin applied to the ::after pseudo-element for the focused item | `{}` |

### Accessibility

`<paper-menu>` has `role="menu"` by default. A multi-select menu will also have
`aria-multiselectable` set. It implements key bindings to navigate through the menu with the up and
down arrow keys, esc to exit the menu, and enter to activate a menu item. Typing the first letter
of a menu item will also focus it.



##&lt;paper-submenu&gt;

`<paper-submenu>` is a nested menu inside of a parent `<paper-menu>`. It
consists of a trigger that expands or collapses another `<paper-menu>`:

```html
<paper-menu>
  <paper-submenu>
    <paper-item class="menu-trigger">Topics</paper-item>
    <paper-menu class="menu-content">
      <paper-item>Topic 1</paper-item>
      <paper-item>Topic 2</paper-item>
      <paper-item>Topic 3</paper-item>
    </paper-menu>
  </paper-submenu>
  <paper-submenu>
    <paper-item class="menu-trigger">Faves</paper-item>
    <paper-menu class="menu-content">
      <paper-item>Fave 1</paper-item>
      <paper-item>Fave 2</paper-item>
    </paper-menu>
  </paper-submenu>
  <paper-submenu disabled>
    <paper-item class="menu-trigger">Unavailable</paper-item>
    <paper-menu class="menu-content">
      <paper-item>Disabled 1</paper-item>
      <paper-item>Disabled 2</paper-item>
    </paper-menu>
  </paper-submenu>
</paper-menu>
```

Just like in `<paper-menu>`, the focused item is highlighted, and the selected
item has bolded text. Please see the `<paper-menu>` docs for which attributes
(such as `multi` and `selected`), and styling options are available for the
`menu-content` menu.


