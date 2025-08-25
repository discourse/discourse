const environment = require("discourse/lib/environment");

environment.setEnvironment("qunit-testing");
require("discourse/deprecation-workflow").default.setEnvironment(environment);

require("discourse/tests/test-boot-ember-cli");
