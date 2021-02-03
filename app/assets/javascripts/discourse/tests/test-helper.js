import config from "../config/environment";
import { setEnvironment } from "discourse-common/config/environment";
import { start } from "ember-qunit";

setEnvironment("testing");

document.addEventListener("discourse-booted", () => {
  let setupTests = require("discourse/tests/setup-tests").default;
  Ember.ENV.LOG_STACKTRACE_ON_DEPRECATION = false;

  setupTests(config.APP);
  start();
});
