---
title: Adding Metadata to a Theme
short_title: Theme metadata
id: theme-metadata
---

You can add various pieces of metadata to a theme. Some are stored in the `about.json` file, and some are stored in the locale files.

## `about.json` <small>[:link: file format info](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848)</small>

**`name`** (string, required): The default name for the theme when installed. This can be changed by admins after the theme is installed

**`component`** (boolean, default `false`): whether the theme should be treated as a component

**`licence_url`** (string, optional): a URL for a license file. A link to this will be displayed in the admin panel. Most themes use this to link to their license file on GitHub

**`about_url`** (string, optional): a URL which contains more information about the theme. A link to this will be displayed in the admin panel. Most themes use this to link to their Meta topic

**`authors`** (string, optional): A string to describe the author of the theme. Displayed in the admin panel.

**`theme_version`** (string, optional): An arbitrary string to describe the version of the theme. Displayed in the admin panel

**`minimum_discourse_version`** (string, optional): the earliest discourse version which this theme is compatible with. If it does not match, the theme will be auto-disabled. Should be in the format `2.4.0.beta1`

**`maximum_discourse_version`** (string, optional): the latest discourse version which this theme is compatible with. If it does not match, the theme will be auto-disabled. Should be in the format `2.4.0.beta1`

## locale files (e.g. `en.yml`) <small>[:link: file format info](https://meta.discourse.org/t/adding-localizable-strings-to-themes-and-theme-components/109867?u=david)</small>

**`theme_metadata.description`**: A localised description of the theme. Displayed in the admin panel

**`theme_metadata.settings.setting_name`**: A localised description of `setting_name`, displayed below the theme setting in the admin panel
