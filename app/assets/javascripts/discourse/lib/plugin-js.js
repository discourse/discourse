const EmberApp = require("ember-cli/lib/broccoli/ember-app");

module.exports = {
  shouldLoadPluginTestJs() {
    return EmberApp.env() === "development" || process.env.LOAD_PLUGINS === "1";
  },
};
