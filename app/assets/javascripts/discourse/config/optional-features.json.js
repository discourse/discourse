const EMBER_MAJOR_VERSION = parseInt(
  require("ember-source/package.json").version.split(".")[0],
  10
);

module.exports = {
  "application-template-wrapper": false,
  "default-async-observers": true,
  "jquery-integration": EMBER_MAJOR_VERSION < 4,
  "template-only-glimmer-components": true,
};
