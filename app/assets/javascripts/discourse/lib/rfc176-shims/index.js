"use strict";

// In core, babel-plugin-ember-modules-api-polyfill takes care of re-writing the new module
// syntax to the legacy Ember globals. For themes and plugins, we need to manually set up
// the modules.
//
// Eventually, Ember RFC176 will be implemented, and we can drop these shims.

const RFC176Data = require("ember-rfc176-data");

module.exports = {
  name: require("./package").name,

  isDevelopingAddon() {
    return true;
  },

  contentFor: function (type) {
    if (type !== "vendor-suffix") {
      return;
    }

    const modules = {};

    for (const entry of RFC176Data) {
      // Entries look like:
      // {
      //   global: 'Ember.expandProperties',
      //   module: '@ember/object/computed',
      //   export: 'expandProperties',
      //   deprecated: false
      // },

      if (entry.deprecated) {
        continue;
      }

      let m = modules[entry.module];
      if (!m) {
        m = modules[entry.module] = [];
      }

      m.push(entry);
    }

    let output = "";
    for (const moduleName of Object.keys(modules)) {
      const exports = modules[moduleName];
      const rawExports = exports
        .map((e) => `${e.export}:${e.global}`)
        .join(",");
      output += `define("${moduleName}", () => {return {${rawExports}}});\n`;
    }

    return output;
  },
};
