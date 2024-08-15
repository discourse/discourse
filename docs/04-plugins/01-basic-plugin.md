---
title: Developing Discourse Plugins - Part 1 - Create a basic plugin
short_title: Basic plugin
id: basic-plugin

---
Building a plugin in Discourse can be really simple, once you learn a couple of quirks. The goal of this post is to create a skeleton plugin and introduce you to the basics.

### Your development environment

Make sure you have a development environment of Discourse running on your computer. I recommend you use [the appropriate setup guide](https://meta.discourse.org/tag/dev-install) and come back when you're done.

### plugin.rb

> :tada: Use https://github.com/discourse/discourse-plugin-skeleton to create a complete discourse plugin skeleton in your plugins directory :tada:

When Discourse starts up, it looks in the `plugins` directory for subdirectories containing a `plugin.rb` file. The `plugin.rb` file has two purposes: it is the manifest for your plugin with the required information about your plugin including: its name, contact information and a description. The second purpose is to initialize any ruby code necessary to run your plugin.

In our case, we won't be adding any ruby code but we still need the `plugin.rb`. Let's create the directory `basic-plugin` with the file `plugin.rb` inside it, with the following contents:

### basic-plugin/plugin.rb
```ruby
# name: basic-plugin
# about: A super simple plugin to demonstrate how plugins work
# version: 0.0.1
# authors: Awesome Plugin Developer
# url: https://github.com/yourusername/basic-plugin
```

Once you've created this file, you should restart your local server and the plugin should be loaded.

### An important Gotcha!

If you're used to regular rails development you might notice that plugins aren't quite as nice when it comes to reloading. In general, when you make changes to your plugin, you should <kbd>Ctrl</kbd>+<kbd>c</kbd> the server to stop it running, then run it again using `bin/ember-cli -u`.

### My changes weren't picked up! :warning: 

Sometimes the cache isn't cleared fully, especially when you create new files or delete old files. To get around this issue, remove your `tmp` folder and start rails again. On a mac you can do it in one command: `rm -rf tmp; bin/ember-cli -u`.

### Checking that your plugin was loaded

Once you've restarted your local server, visit the url `/admin/plugins` (make sure you're [logged in as an admin account](https://meta.discourse.org/t/create-admin-account-from-console/17274) first, as only admins can see the plugin registry).

If everything worked, you should see your plugin in the list:

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/4/7/47a4b274553bd1fb0bba2d2df699ac136ad6a5cc.png" width="690" height="104"> 

Congratulations, you just created your first plugin!

### Let's add some Javascript

Right now your plugin doesn't do anything. Let's add a javascript file that will pop up an alert box when discourse loads. This will be super annoying to any user and is not recommended as an actual plugin, but will show how to insert Javascript into our running application.

Create the following file:

### `plugins/basic-plugin/assets/javascripts/discourse/initializers/alert.js`
```javascript
export default {
  name: 'alert',
  initialize() {
    alert('alert boxes are annoying!');
  }
};
```

Now if you restart your local server, you should see "alert boxes are annoying!" appear on the screen. (If you did not, see the "My Changes weren't picked up" heading above).

Let's step through how this worked:

1. Javascript files placed in `assets/javascripts/discourse/initializers` are executed automatically when the Discourse application loads up. 

2. This particular file `export`s one object, which has a `name` and an `initialize` function. 

3. The `name` has to be unique, so I just called it `alert`.

4. The `initialize()` function is called when the application loads. In our case, all it does is execute our `alert()` code. 

You're now an official Discourse plugin developer! 

---
### More in the series

**Part 1: This topic**
Part 2: [Plugin Outlets](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-2-plugin-outlets/31001)
Part 3: [Site Settings](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-3-custom-settings/31115)
Part 4: [git setup](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-4-git-setup/31272)
Part 5: [Admin interfaces](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-5-admin-interfaces/31761)
Part 6: [Acceptance tests](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-6-acceptance-tests/32619)
Part 7: [Publish your plugin](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-7-publish-your-plugin/101636)
