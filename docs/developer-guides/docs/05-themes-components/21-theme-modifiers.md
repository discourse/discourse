---
title: "Theme modifiers: A brief introduction"
short_title: Theme modifiers
id: theme-modifiers
---

As themes become more ambitious, we've been looking for ways to allow them to manipulate core **server-side** behavior. While they will never be given the same level as control as plugins, we can provide some predefined hooks for themes to manipulate.

Introducing: theme modifiers :partying_face:

They are specified using the `modifiers` key in your theme's `about.json` file.

For a 100% up-to-date list of modifiers, check the database schema at the bottom of [`theme_modifier_set.rb`](https://github.com/discourse/discourse/blob/master/app/models/theme_modifier_set.rb), but here's a quick summary of what we have so far:

- `serialize_topic_excerpts` **boolean** (default false) - always include excerpts when serializing topic lists

- `csp_extensions` **string array** - add directives to the CSP. Works the same as the old "extend_content_security_policy" theme-setting method. But remember, [simple `<script src="">` tags are allowed automatically](https://meta.discourse.org/t/automatically-adding-theme-scripts-to-csp/149028?u=david).

- `svg_icons` **string array** - a list of icons which should be included in the icon subset

- `topic thumbnails` **array of dimensions** - request additional resolutions in the topic thumbnail set. Note that they are generated asynchronously, so you must fall-back to the original image if your requested size is not provided. More information available [in the commit message](https://github.com/discourse/discourse/commit/03818e642a1ae871bffdc0c39c10f05f0b8b0398)

- `serialize_post_user_badges` **string array** - a list of badge names (matching entries in the badges table) to serialize alongside post data. When configured, the system includes the specified user badges with each post for client-side rendering.

One theme making heavy use of these new hooks is https://meta.discourse.org/t/topic-list-thumbnails-theme-component/150602?u=david - check out the code to see how it works.

## Setting-dependent modifiers

Theme modifiers can also be configured to pull their value from a theme setting, allowing site operators to override modifier behavior without editing the theme's code. To make a modifier depend on a setting, use this syntax in your `about.json`:

```json
{
  "modifiers": {
    "modifier_name": {
      "type": "setting",
      "value": "setting_name"
    }
  }
}
```

For example, if you have a theme setting called `show_excerpts` and want it to control the `serialize_topic_excerpts` modifier:

In `settings.yml`:

```yaml
show_excerpts:
  default: false
```

In `about.json`:

```json
{
  "modifiers": {
    "serialize_topic_excerpts": {
      "type": "setting",
      "value": "show_excerpts"
    }
  }
}
```

When the `show_excerpts` setting is changed, the modifier value will automatically update to match. This provides flexibility for site operators to customize theme behavior through the admin UI.
