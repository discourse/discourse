
<!---

This README is automatically generated from the comments in these files:
paper-tab.html  paper-tabs.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-tabs.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-tabs)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-tabs)_


##&lt;paper-tabs&gt;

Material design: [Tabs](https://www.google.com/design/spec/components/tabs.html)

`paper-tabs` makes it easy to explore and switch between different views or functional aspects of
an app, or to browse categorized data sets.

Use `selected` property to get or set the selected tab.

Example:

```html
<paper-tabs selected="0">
  <paper-tab>TAB 1</paper-tab>
  <paper-tab>TAB 2</paper-tab>
  <paper-tab>TAB 3</paper-tab>
</paper-tabs>
```

See <a href="?active=paper-tab">paper-tab</a> for more information about
`paper-tab`.

A common usage for `paper-tabs` is to use it along with `iron-pages` to switch
between different views.

```html
<paper-tabs selected="{{selected}}">
  <paper-tab>Tab 1</paper-tab>
  <paper-tab>Tab 2</paper-tab>
  <paper-tab>Tab 3</paper-tab>
</paper-tabs>

<iron-pages selected="{{selected}}">
  <div>Page 1</div>
  <div>Page 2</div>
  <div>Page 3</div>
</iron-pages>
```

To use links in tabs, add `link` attribute to `paper-tab` and put an `<a>`
element in `paper-tab`.

Example:

<pre><code>
&lt;style is="custom-style">
  .link {
    &#64;apply(--layout-horizontal);
    &#64;apply(--layout-center-center);
  }
&lt;/style>

&lt;paper-tabs selected="0">
  &lt;paper-tab link>
    &lt;a href="#link1" class="link">TAB ONE&lt;/a>
  &lt;/paper-tab>
  &lt;paper-tab link>
    &lt;a href="#link2" class="link">TAB TWO&lt;/a>
  &lt;/paper-tab>
  &lt;paper-tab link>
    &lt;a href="#link3" class="link">TAB THREE&lt;/a>
  &lt;/paper-tab>
&lt;/paper-tabs>
</code></pre>

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-tabs-selection-bar-color` | Color for the selection bar | `--paper-yellow-a100` |
| `--paper-tabs` | Mixin applied to the tabs | `{}` |



##&lt;paper-tab&gt;

`paper-tab` is styled to look like a tab.  It should be used in conjunction with
`paper-tabs`.

Example:

```html
<paper-tabs selected="0">
  <paper-tab>TAB 1</paper-tab>
  <paper-tab>TAB 2</paper-tab>
  <paper-tab>TAB 3</paper-tab>
</paper-tabs>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-tab-ink` | Ink color | `--paper-yellow-a100` |
| `--paper-tab` | Mixin applied to the tab | `{}` |
| `--paper-tab-content` | Mixin applied to the tab content | `{}` |
| `--paper-tab-content-unselected` | Mixin applied to the tab content when the tab is not selected | `{}` |

This element applies the mixin `--paper-font-common-base` but does not import `paper-styles/typography.html`.
In order to apply the `Roboto` font to this element, make sure you've imported `paper-styles/typography.html`.


