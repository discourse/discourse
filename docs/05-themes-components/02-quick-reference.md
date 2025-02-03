---
title: Theme Developer Quick Reference Guide
short_title: Quick reference
id: quick-reference
---

As themes grow more powerful, there's more to remember about how they work. We have loads of detailed documentation under [#howto / #themes](https://meta.discourse.org/tags/c/howto/themes), but if you just need something to jog your memory, this guide may help.

### General Resources

[:scroll: Beginner's guide](https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966)
[:scroll: Designer's guide](https://meta.discourse.org/t/designers-guide-to-discourse-themes/152002/1)
[:scroll: Developer's guide](https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648)
[:paintbrush: Theme Creator](http://theme-creator.discourse.org)
[:desktop_computer: Theme CLI](https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950)
[:notebook_with_decorative_cover: Theme Directory](/c/theme)
[:jigsaw: Component Directory](/c/theme-component)
[:wrench: Theme Modifiers](https://meta.discourse.org/t/theme-modifiers-a-brief-introduction/150605)

### File/Folder Structure <small>[read more](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848)</small>

```
about.json
settings.yml
common/, desktop/, mobile/
  {common|desktop|mobile}.scss
  head_tag.html
  header.html
  after_header.html
  body_tag.html
  footer.html
  embedded.scss (common only)
locales/
  en.yml
  ...
assets/
  (arbitrarily named files, referenced in about.json)
stylesheets/
  (arbitrarily named files, can be imported from each other, and common/desktop/mobile.scss)
javascripts/
  (arbitrarily named files. Supports .js .hbs and .raw.hbs)
```

### about.json <small>[structure info](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848), [available metadata](https://meta.discourse.org/t/adding-metadata-to-a-theme/119205)</small>

```json
{
  "name": "My Theme",
  "component": false,
  "license_url": null,
  "about_url": null,
  "authors": null,
  "theme_version": null,
  "minimum_discourse_version": null,
  "maximum_discourse_version": null,
  "assets": {
    "variable-name": "assets/my-asset.jpg"
  },
  "color_schemes": {
    "My Color Scheme": {
      "primary": "222222"
    }
  }
}
```

### SCSS

[:link: Available CSS Variables](https://github.com/discourse/discourse/blob/master/app/assets/stylesheets/color_definitions.scss)

### Javascript <small>[read more](https://meta.discourse.org/t/using-the-pluginapi-in-site-customizations/41281)</small>

```html
<!-- Define in </head> section of theme-->
<script type="text/discourse-plugin" version="0.8">
  console.log("I am ", api.getCurrentUser().username);
</script>
```

[:link: JS Plugin API](https://github.com/discourse/discourse/blob/main/app/assets/javascripts/discourse/app/lib/plugin-api.gjs)

[:link: Multi-file Javascript](https://meta.discourse.org/t/splitting-up-theme-javascript-into-multiple-files/119369)

### Templates <small>[read more](https://meta.discourse.org/t/adding-plugin-outlets-using-a-theme/32727)</small>

```html
<!-- Define in </head> section of theme-->

<!-- Plugin Outlet -->
<script
  type="text/x-handlebars"
  data-template-name="/connectors/below-footer/arbitrary-unique-name"
>
  This is displayed below the footer
</script>

<!-- Override Core -->
<script type="text/x-handlebars" data-template-name="list/topic-list-item.raw">
  This used to be a topic list item
</script>
```

[:link: Locate outlets](https://meta.discourse.org/t/plugin-outlet-locations-theme-component/100673)

### Settings <small>[read more](https://meta.discourse.org/t/how-to-add-settings-to-your-discourse-theme/82557)</small>

`settings.yml`:

```yaml
fruit:
  default: apples|oranges
  type: list
  description: # Old method. It's better to define these in the locale files (see below)
    en: English Description
    fr: Description Française
```

Access from JavaScript:

```js
console.log(settings.fruit);
```

Access from templates:

```hbs
{{theme-setting "fruit"}}
```

Access from scss:

```scss
html {
  font-size: #{$global-font-size}px;
  background: $site-background;
}
```

### Translations <small>[read more](https://meta.discourse.org/t/adding-localizable-strings-to-themes-and-theme-components/109867)</small>

`locales/en.yml`

```yaml
en:
  my_translation_key: "I love themes"
  theme_metadata: # These are used in the admin panel. They are not made available to your js/hbs files
    description: This theme lets you do amazing things on your Discourse
    settings:
      fruit: A description of the whitelisted_fruits setting
```

Access from JavaScript:

```js
I18n.t(themePrefix("my_translation_key"));
```

Access from templates:

```hbs
{{theme-i18n "my_translation_key"}}
{{d-button label=(theme-prefix "my_translation_key")}}
```
