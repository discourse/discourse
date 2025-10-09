const environment = require("discourse/lib/environment");
const { withSilencedDeprecations } = require("discourse/lib/deprecated");

environment.setEnvironment("qunit-testing");
require("discourse/deprecation-workflow").default.setEnvironment(environment);

withSilencedDeprecations("discourse.native-array-extensions.[]", () => {
  require("discourse/tests/test-boot-ember-cli");
});
