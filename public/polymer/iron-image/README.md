
<!---

This README is automatically generated from the comments in these files:
iron-image.html

Edit those files, and our readme bot will duplicate them over here!
Edit this file, and the bot will squash your changes :)

The bot does some handling of markdown. Please file a bug if it does the wrong
thing! https://github.com/PolymerLabs/tedium/issues

-->

[![Build status](https://travis-ci.org/PolymerElements/iron-image.svg?branch=master)](https://travis-ci.org/PolymerElements/iron-image)

_[Demo and API docs](https://elements.polymer-project.org/elements/iron-image)_


##&lt;iron-image&gt;

`iron-image` is an element for displaying an image that provides useful sizing and
preloading options not found on the standard `<img>` tag.

The `sizing` option allows the image to be either cropped (`cover`) or
letterboxed (`contain`) to fill a fixed user-size placed on the element.

The `preload` option prevents the browser from rendering the image until the
image is fully loaded.  In the interim, either the element's CSS `background-color`
can be be used as the placeholder, or the `placeholder` property can be
set to a URL (preferably a data-URI, for instant rendering) for an
placeholder image.

The `fade` option (only valid when `preload` is set) will cause the placeholder
image/color to be faded out once the image is rendered.

Examples:

  Basically identical to `<img src="...">` tag:

```html
<iron-image src="http://lorempixel.com/400/400"></iron-image>
```

  Will letterbox the image to fit:

```html
<iron-image style="width:400px; height:400px;" sizing="contain"
  src="http://lorempixel.com/600/400"></iron-image>
```

  Will crop the image to fit:

```html
<iron-image style="width:400px; height:400px;" sizing="cover"
  src="http://lorempixel.com/600/400"></iron-image>
```

  Will show light-gray background until the image loads:

```html
<iron-image style="width:400px; height:400px; background-color: lightgray;"
  sizing="cover" preload src="http://lorempixel.com/600/400"></iron-image>
```

  Will show a base-64 encoded placeholder image until the image loads:

```html
<iron-image style="width:400px; height:400px;" placeholder="data:image/gif;base64,..."
  sizing="cover" preload src="http://lorempixel.com/600/400"></iron-image>
```

  Will fade the light-gray background out once the image is loaded:

```html
<iron-image style="width:400px; height:400px; background-color: lightgray;"
  sizing="cover" preload fade src="http://lorempixel.com/600/400"></iron-image>
```

| Custom property | Description | Default |
| --- | --- | --- |
| `--iron-image-placeholder` | Mixin applied to #placeholder | `{}` |
| `--iron-image-width` | Sets the width of the wrapped image | `auto` |
| `--iron-image-height` | Sets the height of the wrapped image | `auto` |


