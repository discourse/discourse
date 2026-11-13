---
title: Create and share a color scheme
short_title: Color scheme
id: color-scheme
---

<div data-theme-toc="true"> </div>

Discourse now supports importing color schemes from remote repository. Here I will demonstrate how you would go about doing this.

### Navigate to colors and add a color scheme.

Head to `/admin/customize/colors` on your site and create a color scheme.

![Creating a color scheme in the admin colors screen|690x451](/assets/color-scheme-1.png)

Tips:

- I used a chrome plugin ([color picker](https://chrome.google.com/webstore/detail/colorpick-eyedropper/ohcpnigalekghcmgcdcenkpelffpdolg?hl=en)) to select colors from an existing image of a palette on the web.

- If you create a theme, assign the color scheme to the theme and preview it, changes will be reflected live.

### Create a new git repository with the color scheme

```sh
mkdir my-awesome-scheme
cd my-awesome-scheme
git init .
vim about.json
```

For `about.json` add a skeleton config file

```json
{
  "name": "My awesome color schemes",
  "about_url": "",
  "license_url": "",
  "color_schemes": {}
}
```

Add a `LICENSE` file, I [usually use MIT](https://github.com/SamSaffron/discourse-solarized/blob/master/LICENSE)

```sh
vim LICENSE
```

### Push changes to GitHub

Check in all your changes:

```sh
git add LICENSE
git add about.json
git commit -am "first commit"
```

Create an account on [GitHub.com](https://github.com) and then create a new repository.

### (Optional) create a topic on Discourse as a home to discuss your colors

Ideally you would create a topic in the #customization:theme category with some screenshots of your color scheme. You will use this as your `about_url`

### Fill in the missing information in your about.json file

- Navigate to your LICENSE page on GitHub, fill in that URL as your `license_url`

- Either use the GitHub project URL or Discourse topic URL as your `about_url`

- Press `Copy to Clipboard` on your color scheme and paste that in to the color_schemes section

At the end of the process your about.json file will look something like:

```json
{
  "name": "Solarized",
  "about_url": "https://github.com/SamSaffron/discourse-solarized",
  "license_url": "https://github.com/SamSaffron/discourse-solarized/blob/master/LICENSE",
  "color_schemes": {
    "Solarized Light": {
      "primary": "586E75",
      "secondary": "EEE8D5",
      "tertiary": "268BD2",
      "quaternary": "CB4B16",
      "header_background": "002B36",
      "header_primary": "93A1A1",
      "highlight": "B58900",
      "danger": "CB4B16",
      "success": "859900",
      "love": "DC322F"
    }
  }
}
```

Check in the change and push to GitHub

```sh
git commit -am "added more details"
git push
```

### Test your color scheme is correct

- Delete your local color scheme
- In the `admin/customize/theme` screen import your theme from GitHub

![Importing a theme from GitHub in the admin customize screen|690x278](/assets/font-component-1.png)

- Visit `admin/customize/colors` and ensure your color scheme looks correct.

:confetti_ball:

You can now easily share your color scheme with others!

### Color palette previews

Palette cards and the palette picker share the SVG in
`frontend/discourse/app/components/svg/single-color-palette-placeholder.gjs`.
The illustration samples the palette rather than reproducing a theme's layout.

![Header and topic preview with numbered color sources](/assets/color-palette-preview.svg)

| Element                 | Palette color       | Opacity |
| ----------------------- | ------------------- | ------- |
| Background              | `secondary`         | 100%    |
| Top strip               | `header_background` | 100%    |
| Topic title             | `primary`           | 75%     |
| Excerpt                 | `primary`           | 45%     |
| Accent pill             | `tertiary`          | 100%    |
| Small buttons           | `primary`           | 35%     |
| Header icons and avatar | `header_primary`    | 32.5%   |

`ColorPalettePreview` exposes the selected palette's colors as `--<name>--preview`
properties, replacing underscores with hyphens. The top strip uses
`header_background`. The accent pill is right-aligned and three small buttons are left-aligned.
The two excerpt lines and small buttons use SVG opacity over `secondary`; they do
not use `primary_medium` or `primary_low`.
The SVG's fallback colors represent Default Light independently of the viewer's
active palette.

All previews include five sidebar menu items, with the first highlighted. Plain
sidebars use `secondary`, a `primary_low` divider and active item, and `primary`
menu marks at 45% opacity. Content has a 24-unit inset from the sidebar and right
edge; menu rows are spaced 18 units apart.

When the default theme uses a tinted sidebar layout, the header and sidebar share a color derived from
`tertiary`: `oklch(from tertiary 96% calc(c * 0.125) h)` for light palettes and
`oklch(from tertiary 10% 0.025 h)` for dark palettes. The variant follows the
site's default theme, independently of the administrator's selected theme. The
tinted variant uses `selected` for its active menu item, falling back to
`tertiary_low`, and rounds the content corner.

The admin palette cards show light and dark palettes together:

![Desktop color palette cards](/assets/color-palette-preview-desktop.png)

On narrow screens, the cards stack vertically:

![Mobile color palette cards](/assets/color-palette-preview-mobile.png)

See also:

https://meta.discourse.org/t/how-to-develop-custom-themes/60848

---

_Last Reviewed by @SaraDev on [date=2022-06-02 time=18:00:00 timezone="America/Los_Angeles"]_
