---
title: Developing Discourse Plugins - Part 3 - Add custom site settings
short_title: Site settings
id: site-settings
---

Previous tutorial: https://meta.discourse.org/t/developing-discourse-plugins-part-2-connect-to-a-plugin-outlet/31001

---

### Site Settings

If you visit `/admin/site_settings` on a Discourse you have administrator capabilities on, you'll see a list of configuration settings. Out of the box, we provide what we think are the best settings for a Discourse install, but we also understand that people want to tweak their installations to make their forum just the way they want it.

Chances are, unless your plugin is very simple, you'll want to add settings that the users of your plugin can change and use to configure functionality. Fortunately, this is quite easy to do!

### `config/settings.yml`

The first thing you'll need to do is create `config/settings.yml` within your plugin folder. This file will outline all the settings your plugin will need. Here's an example file:

```yaml
plugins:
  awesomeness_enabled:
    default: true
    client: true
  awesomeness_max_volume:
    default: 10
    client: true
```

The file needs to be in [YAML](https://en.wikipedia.org/wiki/YAML) format. YAML can be quite picky so if Discourse is having trouble loading your settings I suggest you try validating your YAML with a tool like [YAMLint](http://www.yamllint.com/).

I'll explain the example file in detail. The top level is `plugins` and that tells Discourse that we want these settings to appear under "Plugins" in the site settings.

After that, there are two settings declared, `awesomeness_enabled` and `awesomeness_max_volume`. Discourse reasons the type of the settings from the default, so `awesomeness_enabled` is a boolean and `awesomeness_max_volume` is a number.

The `client: true` is important to understand. Discourse is made up of two major applications, the server side API written in Ruby on Rails, and the client side application written in Ember.js. By default, we don't expose settings to the Ember.js client app unless you add `client: true`. We do this because some settings are private like API keys and should not be sent to end users. Also, if we sent every setting to the client that could be a lot for end users to download!

In our example case, we want both of those settings to be accessible in the JavaScript world as well as the server side world.

### An important second step

Before you can use your newly added site settings, you need to add translations for them. Since Discourse supports many languages, any text you add will have to support being translated into other languages.

Let's create the translations for our settings in English:

**`config/locales/server.en.yml`**

```yaml
en:
  site_settings:
    awesomeness_enabled: "Is this plugin awesome?"
    awesomeness_max_volume: "What is the maximum volume possible?"
```

The labels we added in that file will be displayed in the admin section. It's a good idea to be clear as possible as to what the setting accomplishes.

### Declaring the setting as the 'enabled setting'

Now that we have our site setting, we should tell Discourse that it's the one that turns our features on and off.

Open your `plugin.rb` file and add the following line below the metadata comments:

```rb
enabled_site_setting :awesomeness_enabled
```

Make sure to start all of your other settings with "`awesomeness_`" in order for the settings button at `/admin/plugins` to work correctly.

### Accessing your new Settings

First, you'll need to restart your development server to have the settings take effect. Once you do that, the settings should be available to your server and client side code.

We automatically inject the site settings into most JavaScript objects, so if you are declaring a `Component`, `Controller`, `Route`, `View` or `Model` you should be able to access the site setting by simply using `this.siteSettings.awesomeness_enabled`. In most handlebars templates you should also be able to say `{{siteSettings.awesomeness_enabled}}` and the setting value will be displayed.

We haven't covered much Ruby stuff in this series yet, but if you want to access the site settings in the Ruby application you can do so via: `SiteSetting.awesomeness_enabled`

Now go forth and add custom settings to your plugins!

---

### More in the series

Part 1: [Plugin Basics](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-1/30515)
Part 2: [Plugin Outlets](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-2-plugin-outlets/31001)
**Part 3: This topic**
Part 4: [git setup](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-4-git-setup/31272)
Part 5: [Admin interfaces](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-5-admin-interfaces/31761)
Part 6: [Acceptance tests](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-6-acceptance-tests/32619)
Part 7: [Publish your plugin](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-7-publish-your-plugin/101636)
