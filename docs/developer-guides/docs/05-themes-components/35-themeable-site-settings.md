---
title: Controlling site settings with themes
short_title: Themeable site settings
id: themeable-site-settings
---

Themeable site settings allow a theme (not components) to override a small subset of core site settings, which generally control parts of the UI and other minor functionality. This allows themes to have a greater control over the full site experience.

## :heavy_plus_sign: Adding themeable site settings

All themeable site settings are defined in the core `config/site_settings.yml` file. Any setting with `themeable: true` will be available to themes.

To override the default site setting value when the theme is installed, you can add this section in your theme's `about.json` file:

```json
{
  "theme_site_settings": {
    "enable_welcome_banner": true
  }
}
```

Any future updates to this value in your theme _will not change the saved database value_. This is to prevent themes from overriding site settings that the site admin has already changed.

## :symbols: Supported types

The types for themeable site settings are identical to the core site setting types. You do not need to define the type in `about.json`; just make sure the value is a valid one based on the site setting type.

## :wrench: Using themeable site settings

The core `siteSettings` service in JS is used to access the values of themeable site settings. You can access them like this:

```javascript
@service siteSettings;

this.siteSettings.enable_welcome_banner;
```

This will also work in .gjs templates. Generally, you will not need to access these values in your theme, since the point of changing these in the theme is to change the behaviour of the core UI itself.

## :capital_abcd: Setting description and localizations

The core site setting description is used when showing themeable site settings to site admins on the theme config page, and also on the `/admin/config/themeable-site-settings` overview page.

## :link: Related Topics

- https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648
