---
title: Developing Discourse Plugins - Part 2 - Connect to a plugin outlet
short_title: Plugin outlet
id: plugin-outlet
---

Previous tutorial: https://meta.discourse.org/t/developing-discourse-plugins-part-1-create-a-basic-plugin/30515

---

### Getting Started: Handlebars Templates

Discourse's client application is written using the Ember.js Javascript framework. Ember uses [Handlebars](https://guides.emberjs.com/v4.12.0/components) for all HTML templates. There's a great introduction to the templating language at that link, so definitely read it thoroughly.

### The Problem: Adding elements to the Discourse User Interface

Many plugins need to add and extend the Discourse web interface. We provide a mechanism to do this called plugin outlets in handlebars templates.

If you browse the discourse handlebars templates, you'll often see the following markup:

```hbs
<PluginOutlet @name="edit-topic" />
```

This is declaring a plugin outlet called "edit-topic". It's an extension point in the template that plugin authors can leverage to add their own handlebars markup.

When authoring your plugin, look in the discourse handlebars templates (in `.hbs` files) you want to change for a `<PluginOutlet />`. If there isn't one, just ask us to extend it! We'll happily add them if you have a good use case. If you want to make it easier and faster for us to do that, please submit a pull request on github!

> :exclamation: If you want to see some of the places where plugin outlets exist, you can run the following command if you're on OSX or Linux:
>
> ```sh
> git grep "<PluginOutlet" -- "*.hbs"
> ```

You can also display the plugin outlets on a Discourse site by turning on the [Discourse Developer Toolbar](https://meta.discourse.org/t/introducing-discourse-developer-toolbar/346215). Just type `enableDevTools()` in the browser console on a Discourse forum and click the plug icon that appears on the left side of the page.

### Connecting to a Plugin Outlet

Once you've found the plugin outlet you want to add to, you have to write a `connector` for it. A connector is really just a handlebars template whose filename includes `connectors/<outlet name>` in it.

For example, if the Discourse handlebars template has:

```hbs
<PluginOutlet @name="evil-trout" />
```

Then any handlebars files you create in the `connectors/evil-trout` directory
will automatically be appended. So if you created the file:

`plugins/hello/assets/javascripts/discourse/connectors/evil-trout/hello.hbs`

With the contents:

```hbs
<b>Hello World</b>
```

Discourse would insert `<b>Hello World</b>` at that point in the template.

Note that we called the file `hello.hbs` -- The final part of the filename does not matter, but it must be unique across every plugin. It's useful to name it something descriptive of what you are extending it to do. This will make debugging easier in the future.

### Troubleshooting

- Double check the name of the connector and make sure it matches the plugin name perfectly.

### More information

https://meta.discourse.org/t/using-plugin-outlet-connectors-from-a-theme-or-plugin/32727

---

### More in the series

Part 1: [Plugin Basics](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-1/30515)
**Part 2: This topic**
Part 3: [Site Settings](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-3-custom-settings/31115)
Part 4: [git setup](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-4-git-setup/31272)
Part 5: [Admin interfaces](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-5-admin-interfaces/31761)
Part 6: [Acceptance tests](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-6-acceptance-tests/32619)
Part 7: [Publish your plugin](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-7-publish-your-plugin/101636)
