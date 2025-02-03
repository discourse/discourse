---
title: "(not recommended) Overriding Discourse templates from a Theme or Plugin"
short_title: Overriding templates
id: overriding-templates
---

Ideally, when customizing Discourse via themes/plugins, you should use CSS, [the JavaScript Plugin API](https://meta.discourse.org/t/a-new-versioned-api-for-client-side-plugins/40051), or [plugin outlets](https://meta.discourse.org/t/connect-your-theme-to-plugin-outlets-to-inject-templates-with-custom-content/32727). If none of these work for your use-case, feel free to open a PR to Discourse core or start a #dev topic here on Meta. We're always happy to discuss adding new outlets/APIs to make customization easier.

If you've exhausted all other options, you may need to resort to template overrides. This technique allows you to override the entire template of any Ember Component or Route from your theme/plugin.

> :rotating_light: **This is not a recommended way of customizing Discourse.** Day-to-day changes in Discourse core **will** conflict with your template override eventually, potentially causing catastrophic errors when rendering the forum.
>
> If you decide to take this approach, make sure you have sufficient automated testing and QA processes to detect regressions. If you distribute a theme/plugin with template overrides, please ensure forum admins are aware of the stability risks your theme/plugin carries.

> :rotating_light: :rotating_light: :rotating_light: **October 2023 Update**: For new features, Discourse is increasingly moving towards using components authored using Ember's `.gjs` file format. Templates for these components are defined inline, and cannot be overridden by themes/plugins.
>
> Going forward, all template customizations should be done using [Plugin Outlets](https://meta.discourse.org/t/using-plugin-outlet-connectors-from-a-theme-or-plugin/32727)

[details=I understand this will break in the near future, show me the docs anyway]

## Overriding Component Templates

To override an Ember Component template (i.e. anything under [`components/*`](https://github.com/discourse/discourse/tree/main/app/assets/javascripts/discourse/app/components) in Discourse core), you should create an identically-named `.hbs` in your theme/plugin. For example, to override the template for the `badge-button` component in Discourse core, you would create a template file in your theme/plugin at this location:

:art: `{theme}/javascripts/discourse/templates/components/badge-button.hbs`

:electric_plug: `{plugin}/assets/javascripts/discourse/templates/components/badge-button.hbs`

The override must always be nested inside the `/templates` directory, even if the core component has a 'colocated' template.

## Overriding Route Templates

Overriding route templates (i.e. all the non-component templates under [`templates/*`](https://github.com/discourse/discourse/tree/main/app/assets/javascripts/discourse/app/templates)) works in the same way as components. Create an identically named template in your theme/plugin. For example, to override `discovery.hbs` in core, you would create a file like

:art: `{theme}/javascripts/discourse/templates/discovery.hbs`

:electric_plug: `{plugin}/assets/javascripts/discourse/templates/discovery.hbs`

## Overriding 'Raw' Templates (`.hbr`)

Discourse's "raw" template system will soon be replaced by regular Ember components. But in the meantime, overriding raw templates works in the same way as Ember templates. For example, to override `topic-list-item.hbr` in core, you could create a file like:

:art: `{theme}/javascripts/discourse/templates/list/topic-list-item.hbr`

:electric_plug: `{plugin}/assets/javascripts/discourse/templates/list/topic-list-item.hbr`

## Interaction between multiple themes / plugins

If multiple installed themes/plugins override the same template, the 'winner' is the one with the lowest-numbered ranking in this list:

1. Theme overrides (highest theme 'id' wins)
2. Plugin overrides (latest alphabetical plugin name wins)
3. Core

This precedence also means that you can override plugin templates from themes. Technically you can also override theme templates from other themes, and plugin templates from other plugins, but the behavior can be surprising because of the dependence on plugin-name and theme-id.

## How does this work?

Discourse assembles and prioritises templates in the [DiscourseTemplateMap](https://github.com/discourse/discourse/blob/666fd43c37/app/assets/javascripts/discourse-common/addon/lib/discourse-template-map.js) class. For colocated component templates, that information is used [during app initialization](https://github.com/discourse/discourse/blob/666fd43c37/app/assets/javascripts/discourse/app/initializers/colocated-template-overrides.js) to replace the core template associations. For all other templates, the map is used by [the resolver at runtime](https://github.com/discourse/discourse/blob/666fd43c37/app/assets/javascripts/discourse-common/addon/resolver.js#L327) to fetch the correct template.
[/details]
