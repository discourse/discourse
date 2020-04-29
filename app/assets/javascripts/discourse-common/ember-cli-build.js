"use strict";

const EmberAddon = require("ember-cli/lib/broccoli/ember-addon");

module.exports = function(defaults) {
  let app = new EmberAddon(defaults, {});

  return app.toTree();
};
