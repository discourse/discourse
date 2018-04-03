// A small helper to inject theme settings into
// context objects of handlebars templates used
// in themes

import { registerHelper } from 'discourse-common/lib/helpers';

function inject(context, key, value) {
  if (typeof value === "string") {
    value = value.replace(/\\u0022/g, '"');
  }

  if (!context.get("themeSettings")) {
    context.set("themeSettings", {});
  }
  context.set(`themeSettings.${key}`, value);
}

registerHelper('theme-setting-injector', function(arr, hash) {
  inject(hash.context, hash.key, hash.value);
});

Handlebars.registerHelper('theme-setting-injector', function(hash) {
  inject(hash.data.root, hash.hash.key, hash.hash.value);
});
