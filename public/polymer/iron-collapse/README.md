
<!---

This README is automatically generated from the comments in these files:
iron-collapse.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build Status](https://travis-ci.org/PolymerElements/iron-collapse.svg?branch=master)](https://travis-ci.org/PolymerElements/iron-collapse)

_[Demo and API Docs](https://elements.polymer-project.org/elements/iron-collapse)_


##&lt;iron-collapse&gt;

`iron-collapse` creates a collapsible block of content.  By default, the content
will be collapsed.  Use `opened` or `toggle()` to show/hide the content.

```html
<button on-click="toggle">toggle collapse</button>

<iron-collapse id="collapse">
  <div>Content goes here...</div>
</iron-collapse>

...

toggle: function() {
  this.$.collapse.toggle();
}
```

`iron-collapse` adjusts the height/width of the collapsible element to show/hide
the content.  So avoid putting padding/margin/border on the collapsible directly,
and instead put a div inside and style that.

```html
<style>
  .collapse-content {
    padding: 15px;
    border: 1px solid #dedede;
  }
</style>

<iron-collapse>
  <div class="collapse-content">
    <div>Content goes here...</div>
  </div>
</iron-collapse>
```


