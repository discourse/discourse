---
title: Update themes and plugins to support automatic dark mode
short_title: Dark mode
id: dark-mode

---
Previously, all colors in Discourse were stored as SCSS variables. To support [automatic dark mode color scheme switching](https://meta.discourse.org/t/automatic-dark-mode-color-scheme-switching/161593), we have converted these colors in core to custom CSS properties. You can easily see the full list in the inspector now: 

![image|638x500, 100%](/assets/dark-mode-1.jpeg) 

Themes and plugins need to switch all the `$color` SCSS variables used in stylesheets to the `--color` CSS property equivalents. In most cases, this is a simple find and replace task:

```diff
-   background-color: $primary-very-low;
+   background-color: var(--primary-very-low);
```

But there are some cases where a theme or a plugin is using a more complex variation of a color, for example, when darkening or lightening using SCSS color functions. These cases require a more complex refactoring, and for this we have added the capacity to extend color definitions in themes and plugins. 

#### In plugins

[This commit](https://github.com/discourse/discourse-encrypt/commit/d8758ec7657ce073e6d42b30c4a7c5a2cd0ffeae) in the discourse-encrypt plugin is a good and simple example of such a refactor. It moves a `mix($color1, $color2)` SCSS declaration into a separate file and stores it as a CSS custom property. Then the new file is registered as a `:color_definitions` asset which ensures that the newly declared color property is included in the color definitions stylesheet. 

#### In themes 

In themes, you can do the same thing by declaring CSS custom properties in the `common/color_definitions.scss` stylesheet. You can look at this [commit in the graceful theme](https://github.com/discourse/graceful/commit/b44f048cd97bf33b8d3316974844476a25466ee0) for an example. 

### Some additional notes

- when using transparent colors via the `rgba($color, 0.5)` function, SCSS accepts HEX and RGB colors in the first parameter, whereas CSS custom properties only accept an RGB color. That is why we have introduced the `hexToRGB()` helper and some properties with the `--rgb` suffix in the color definitions. An example: 

```scss
// color_definitions.scss
:root {
  --primary: #{$primary};
  --primary-rgb: #{hexToRGB($primary)};
}

// other stylesheet
.element {
  background-color: rgba(var(--primary-rgb), 0.05);
}
```
- note that in the snippet above, the SCSS variable is interpolated when passed to a custom property. That is a requirement in SCSS, see https://sass-lang.com/documentation/style-rules/declarations for more details.
- the CSS `var()` declaration can fallback to a second value if the first one is not available, as in, when writing `var(--color1, red)`, CSS will fallback to the red color if the `--color1` property is not found. In plugins, we use the SCSS color variables as fallbacks to ensure compatibility with previous versions of Discourse. So the earlier example, would look like this with a fallback: 

```diff
-   background-color: $primary-very-low;
+   background-color: var(--primary-very-low, $primary-very-low);
```
