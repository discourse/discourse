---
title: Structure of themes and theme components
short_title: Theme structure
id: theme-structure
---

Discourse supports [native themes](https://meta.discourse.org/t/native-theme-support/47494/26) that can be sourced from a `.tar.gz` archive or from a remote git repository including [private repositories](https://meta.discourse.org/t/how-to-source-a-theme-from-a-private-git-repository/82584).

![56|690x364,50%](/assets/theme-structure-1.png)

An example theme is at: https://github.com/SamSaffron/discourse-simple-theme

![32|341x499](/assets/theme-structure-2.png)

The git repository will be checked for updates ([once a day](https://github.com/discourse/discourse/blob/master/app/jobs/scheduled/check_out_of_date_themes.rb)), or by using the <kbd>Check for Updates</kbd> button. When changes are detected the <kbd>Check for Updates</kbd> button will change to the <kbd>Update to Latest</kbd>.

![image|299x90,50%](/assets/theme-structure-3.png)

To create a theme you need to follow a specific file structure. These are the files you may include:

```
about.json (required)

common/common.scss
common/header.html
common/after_header.html
common/footer.html
common/head_tag.html
common/body_tag.html
common/embedded.scss

desktop/desktop.scss
desktop/header.html
desktop/after_header.html
desktop/footer.html
desktop/head_tag.html
desktop/body_tag.html

mobile/mobile.scss
mobile/header.html
mobile/after_header.html
mobile/footer.html
mobile/head_tag.html
mobile/body_tag.html

locales/en.yml
locales/{locale}.yml

stylesheets/{anything}/{anything}/{anything}.scss

javascripts/{anything}.js
javascripts/{anything}.hbs
javascripts/{anything}.hbr

assets/{asset_filename}

settings.yml
```

Any of these files :arrow_up: are optional, so you only need to create the ones you need.

For those looking to split theme SCSS into multiple files, that's now possible.

https://meta.discourse.org/t/splitting-up-theme-scss-into-multiple-files/115126

For those looking to split up theme into multiple JS files, just add the JS files you want into the javascripts directory.

The `about.json` file structure is:

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

Instructions on how to add settings to your theme available here: https://meta.discourse.org/t/how-to-add-settings-to-your-discourse-theme/82557?u=osama.

To tell Discourse that you are going to add a **theme component** and not a full theme just add the line `"component": true` to the `about.json` file

The file structure matches the theme custom CSS / HTML.

### Further reading

Check out the other articles with the #themes::tag tag.

:information_source: See also:

- https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648
- https://meta.discourse.org/t/discourse-theme-cli-console-app-to-help-you-build-themes/82950
- https://meta.discourse.org/t/include-images-and-fonts-in-themes/62459?source_topic_id=60848

---

_Last Reviewed by @SaraDev on [date=2022-08-15 time=14:00 timezone="America/Los_Angeles"]_
