"use strict";

module.exports = {
  name: require("./package").name,
  options: {
    autoImport: {
      alias: {
        handlebars: "handlebars/dist/cjs/handlebars.js"
      }
    }
  }
};
