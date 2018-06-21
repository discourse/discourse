// A small helper to inject theme settings into
// context objects of handlebars templates used
// in themes

import { registerHelper } from "discourse-common/lib/helpers";

function inject(context, key, value) {
  if (typeof value === "string") {
    value = value.replace(/\\u0022/g, '"');
  }

  if (!(context instanceof Ember.Object)) {
    injectPlainObject(context, key, value);
    return;
  }

  if (!context.get("themeSettings")) {
    context.set("themeSettings", {});
  }
  context.set(`themeSettings.${key}`, value);
}

function injectPlainObject(context, key, value) {
  if (!context.themeSettings) {
    _.assign(context, { themeSettings: {} });
  }
  _.assign(context.themeSettings, { [key]: value });
}

registerHelper("theme-setting-injector", function(arr, hash) {
  inject(hash.context, hash.key, hash.value);
});

Handlebars.registerHelper("theme-setting-injector", function(hash) {
  inject(this, hash.hash.key, hash.hash.value);
});
