// A small helper to inject theme settings into
// context objects of handlebars templates used
// in themes

import { registerHelper } from "discourse-common/lib/helpers";

function inject(context, parent, key, value) {
  if (typeof value === "string") {
    value = value.replace(/\\u0022/g, '"');
  }

  if (!(context instanceof Ember.Object)) {
    injectPlainObject(context, parent, key, value);
    return;
  }

  if (!parent) {
    context.set(key, value);
    return;
  }

  if (parent && !context.get(parent)) {
    context.set(parent, {});
  }
  context.set(`${parent}.${key}`, value);
}

function injectPlainObject(context, parent, key, value) {
  if (!parent) {
    _.assign(context, { [key]: value });
    return;
  }

  if (!context[parent]) {
    _.assign(context, { [parent]: {} });
  }
  _.assign(context[parent], { [key]: value });
}

registerHelper("theme-injector", function(arr, hash) {
  inject(hash.context, hash.parent, hash.key, hash.value);
});

Handlebars.registerHelper("theme-injector", function(hash) {
  inject(this, hash.hash.parent, hash.hash.key, hash.hash.value);
});
