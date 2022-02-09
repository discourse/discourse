import config from "../config/environment";
import { setEnvironment } from "discourse-common/config/environment";
import { start } from "ember-qunit";
import loadEmberExam from "ember-exam/test-support/load";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";

setEnvironment("testing");

document.addEventListener("discourse-booted", () => {
  const script = document.getElementById("plugin-test-script");
  if (script && !requirejs.entries["discourse/tests/active-plugins"]) {
    throw new Error(
      `Plugin JS payload failed to load from ${script.src}. Is the Rails server running?`
    );
  }

  let setupTests = require("discourse/tests/setup-tests").default;
  const skippingCore =
    new URLSearchParams(window.location.search).get("qunit_skip_core") === "1";
  Ember.ENV.LOG_STACKTRACE_ON_DEPRECATION = false;

  document.body.insertAdjacentHTML(
    "afterbegin",
    `
      <div id="qunit"></div>
      <div id="qunit-fixture"></div>
      <div id="ember-testing-container" style="position: fixed">
        <div id="ember-testing"></div>
      </div>
    `
  );

  setup(QUnit.assert);
  setupTests(config.APP);
  let loader = loadEmberExam();

  if (loader.urlParams.size === 0 && !QUnit.config.seed) {
    // If we're running in browser, default to random order. Otherwise, let Ember Exam
    // handle randomization.
    QUnit.config.seed = true;
  }

  loader.loadModules();
  start({
    setupTestContainer: false,
    loadTests: false,
    setupEmberOnerrorValidation: !skippingCore,
  });
});
window.EmberENV.TESTS_FILE_LOADED = true;
