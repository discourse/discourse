
<!---

This README is automatically generated from the comments in these files:
paper-card.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build Status](https://travis-ci.org/PolymerElements/paper-card.svg?branch=master)](https://travis-ci.org/PolymerElements/paper-card)

_[Demo and API Docs](https://elements.polymer-project.org/elements/paper-card)_


##&lt;paper-card&gt;

Material design: [Cards](https://www.google.com/design/spec/components/cards.html)

`paper-card` is a container with a drop shadow.

Example:

```html
<paper-card heading="Card Title">
  <div class="card-content">Some content</div>
  <div class="card-actions">
    <paper-button>Some action</paper-button>
  </div>
</paper-card>
```

Example - top card image:

```html
<paper-card heading="Card Title" image="/path/to/image.png">
  ...
</paper-card>
```

### Accessibility

By default, the `aria-label` will be set to the value of the `heading` attribute.

### Styling

The following custom properties and mixins are available for styling:

| Custom property | Description | Default |
| --- | --- | --- |
| `--paper-card-background-color` | The background color of the card | `--primary-background-color` |
| `--paper-card-header-color` | The color of the header text | `#000` |
| `--paper-card-header` | Mixin applied to the card header section | `{}` |
| `--paper-card-header-text` | Mixin applied to the title in the card header section | `{}` |
| `--paper-card-header-image` | Mixin applied to the image in the card header section | `{}` |
| `--paper-card-header-image-text` | Mixin applied to the text overlapping the image in the card header section | `{}` |
| `--paper-card-content` | Mixin applied to the card content section | `{}` |
| `--paper-card-actions` | Mixin applied to the card action section | `{}` |
| `--paper-card` | Mixin applied to the card | `{}` |


