// A small helper to inject theme settings into
// context objects of handlebars templates used
// in themes

import { registerHelper } from 'discourse-common/lib/helpers';

registerHelper('theme-setting-injector', function(arr, hash) {
  const context = hash.context;
  let value = hash.value;

  if (typeof value === "string") {
    value = value.replace(/\\u0022/g, '"');
  }

  if (!context.get("themeSettings")) {
    context.set("themeSettings", {});
  }
  context.set(`themeSettings.${hash.key}`, value);
});
