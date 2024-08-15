---
title: Using the PluginAPI in Site Customizations
short_title: PluginAPI
id: pluginapi

---
Using the [client side Plugin API](https://meta.discourse.org/t/a-new-versioned-api-for-client-side-plugins/40051) is the safest way to build Discourse Javascript plugins and themes while respecting backwards compatibility. 

However, some people have made simple customizations using the Admin > Customization > CSS/HTML and dropping some Javascript into a `<script>` tag. Previously, it was very difficult to use the `withPluginApi` to access objects using the Discourse container.

In the latest tests-passed build of Discourse I've added the ability to use the pluginAPI via a site customation.

To use it, you just need to add some attributes to a script tag in your `</HEAD>` customization:

```html
<script type="text/discourse-plugin" version="0.1">
  // you can use the `api` object here!
  api.decorateCooked($elem => $elem.css({ backgroundColor: 'yellow' }));
</script>
```

When you save the customization, Discourse will transpile the ES2015 code within the tag so you can use the latest Javascript features. Additionally, it wraps the code in an initializer and runs it through `withPluginApi` so you don't have to bother with that. Just specify the version of the `api` object you want and Discourse will give it to you, providing safe backwards compatibility.

If the compilation of the ES2015 fails for some reason, when you view source on your page you'll see the error in a `<script type='text/discourse-js-error'>` block. Fix what it says and re-save your customization and you'll be good to go.
