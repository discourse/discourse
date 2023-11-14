"use strict";

const Funnel = require("broccoli-funnel");
const rawHandlebarsCompiler = require("./raw-handlebars-compiler");

module.exports = {
  name: require("./package").name,

  treeForApp() {
    const hbr = new Funnel(this.app.trees.app, {
      include: ["**/*.hbr"],
    });

    return rawHandlebarsCompiler(hbr);
  },
};
