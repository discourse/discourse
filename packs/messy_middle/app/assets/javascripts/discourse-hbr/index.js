"use strict";

const rawHandlebarsCompiler = require("./raw-handlebars-compiler");

module.exports = {
  name: require("./package").name,

  treeForApp() {
    return rawHandlebarsCompiler(this.app.trees.app);
  },
};
