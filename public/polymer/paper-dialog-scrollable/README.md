
<!---

This README is automatically generated from the comments in these files:
paper-dialog-scrollable.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/paper-dialog-scrollable.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-dialog-scrollable)

_[Demo and API docs](https://elements.polymer-project.org/elements/paper-dialog-scrollable)_


##&lt;paper-dialog-scrollable&gt;

Material design: [Dialogs](https://www.google.com/design/spec/components/dialogs.html)

`paper-dialog-scrollable` implements a scrolling area used in a Material Design dialog. It shows
a divider at the top and/or bottom indicating more content, depending on scroll position. Use this
together with elements implementing `Polymer.PaperDialogBehavior`.

```html
<paper-dialog-impl>
  <h2>Header</h2>
  <paper-dialog-scrollable>
    Lorem ipsum...
  </paper-dialog-scrollable>
  <div class="buttons">
    <paper-button>OK</paper-button>
  </div>
</paper-dialog-impl>
```

It shows a top divider after scrolling if it is not the first child in its parent container,
indicating there is more content above. It shows a bottom divider if it is scrollable and it is not
the last child in its parent container, indicating there is more content below. The bottom divider
is hidden if it is scrolled to the bottom.

If `paper-dialog-scrollable` is not a direct child of the element implementing `Polymer.PaperDialogBehavior`,
remember to set the `dialogElement`:

```html
<paper-dialog-impl id="myDialog">
  <h2>Header</h2>
  <div class="my-content-wrapper">
    <h4>Sub-header</h4>
    <paper-dialog-scrollable>
      Lorem ipsum...
    </paper-dialog-scrollable>
  </div>
  <div class="buttons">
    <paper-button>OK</paper-button>
  </div>
</paper-dialog-impl>

<script>
  var scrollable = Polymer.dom(myDialog).querySelector('paper-dialog-scrollable');
  scrollable.dialogElement = myDialog;
</script>
```

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-dialog-scrollable` | Mixin for the scrollable content | {} |


