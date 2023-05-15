# HSLuv Sass
[![Build Status](https://github.com/hsluv/hsluv-sass/actions/workflows/ci.yml/badge.svg)](https://github.com/hsluv/hsluv-sass/actions/workflows/ci.yml?query=branch%3Amaster)
[![Package Version](https://img.shields.io/npm/v/hsluv-sass.svg)](https://www.npmjs.com/package/hsluv-sass)

Pure Sass [HSLuv](http://www.hsluv.org) implementation.

This package attempts to match the canonical implementation as closely as possible,
but not break sass best practices and common patterns. Important deviations
include

- RGB color components range from 0 to 255, not 0 to 1
- Testing precision is lowered significantly

## Usage

### Installation

```
npm install hsluv-sass
```

### Example

Create `demo.csss`:

With [`@use`](https://sass-lang.com/documentation/at-rules/use):

```scss
@use "./node_modules/hsluv-sass" as hsluv;

.example {
  color: hsluv.hsluv(23.2, 83.4%, 43.7%);
  background-color: hsluv.hpluv(250.4, 100%, 59.1%);
}
```

With [`@import`](https://sass-lang.com/documentation/at-rules/import):

```scss
@import "./node_modules/hsluv-sass";

.example {
  color: hsluv(23.2, 83.4%, 43.7%);
  background-color: hpluv(250.4, 100%, 59.1%);
}
```

Compile:

```bash
$ npx sass demo.scss 
```

Emitted css:

```css
.example {
  color: #a84c27;
  background-color: #738fc0;
}
```

### API

```scss
hsluv($hue, $saturation, $lightness) //=> color
```

Creates a sass color object in HSLuv color space. 

```scss
hpluv($hue, $saturation, $lightness) //=> color
```

Creates a sass color object in HPLuv color space. 

```scss
hsluva($hue, $saturation, $lightness, $alpha: 1) //=> color
```

Creates a sass color object in HSLuv color space with transparency.

```scss
hpluva($hue, $saturation, $lightness, $alpha: 1) //=> color
```

Creates a sass color object in HPLuv color space with transparency. 

#### Parameters

- `$hue` — The hue of the color. A number between 0 and 360 degrees, inclusive.
- `$saturation` — The saturation of the color. Must be a number between 0% and 100%, inclusive.
- `$lightness` — The lightness of the color. Must be a number between 0% and 100%, inclusive.
- `$alpha` - The opacity of the color. Must be a number between 0 and 1, inclusive.

All function support passing an HSL map directly and omitting the `$saturation` and `$lightness` parameters. If unitless, the `h` value must be in radians.

```scss
.example {
  color: hsluv((h: 0.4049164, s: 83.4, l: 43.7));
  background-color: hpluv((h: 4.3703044, s: 100, l: 59.1));
}
```

## Testing

Tested with [True](https://www.oddbird.net/true/docs/).
Continuous integration tests againsts the last several version of node on multiple platforms.

You can locally test after installing npm dependencies. Just run
`npm test`.

## Support

Have a question or need help? [Open an issue](https://github.com/hsluv/hsluv-sass/issues/new)

## License

This project is provided under the terms of the [MIT License](LICENSE).

Original version by **Cameron Little** · [Github](https://github.com/apexskier) · [Twitter](https://twitter.com/apexskier) · [CodePen](https://codepen.com/apexskier)
