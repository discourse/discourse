"use strict";

const commonBabelConfig = require("../discourse/lib/common-babel-config");

module.exports = {
  name: require("./package").name,
  options: {
    autoImport: {
      alias: {
        handlebars: "handlebars/dist/cjs/handlebars.js",
      },
    },

    ...commonBabelConfig(),
  },

  isDevelopingAddon() {
    return true;
  },
};
