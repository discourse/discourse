"use strict";

module.exports = {
  name: require("./package").name,
  options: {
    autoImport: {
      alias: {
        handlebars: "handlebars/dist/cjs/handlebars.js",
      },
    },

    babel: {
      plugins: [
        [
          require.resolve("decorator-transforms"),
          {
            runEarly: true,
          },
        ],
      ],
    },

    "ember-cli-babel": {
      disableDecoratorTransforms: true,
    },
  },

  isDevelopingAddon() {
    return true;
  },
};
