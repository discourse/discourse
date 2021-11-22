import config from "../config/environment";
import { setEnvironment } from "discourse-common/config/environment";
import { start } from "ember-qunit";
import loadEmberExam from "ember-exam/test-support/load";

setEnvironment("testing");

document.addEventListener("discourse-booted", () => {
  let setupTests = require("discourse/tests/setup-tests").default;
  Ember.ENV.LOG_STACKTRACE_ON_DEPRECATION = false;

  document.body.insertAdjacentHTML(
    "afterbegin",
    `
      <div id="qunit"></div>
      <div id="qunit-fixture"></div>
      <div id="ember-testing-container" class="full-screen">
        <div id="ember-testing"></div>
      </div>
    `
  );

  setupTests(config.APP);
  let loader = loadEmberExam();
  loader.loadModules();
  start({ setupTestContainer: false, loadTests: false });
});
