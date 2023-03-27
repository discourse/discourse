import config from "../config/environment";
import { setEnvironment } from "discourse-common/config/environment";
import { start } from "ember-qunit";
import loadEmberExam from "ember-exam/test-support/load";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";
import Ember from "ember";
import setupTests from "discourse/tests/setup-tests";

setEnvironment("testing");

document.addEventListener("discourse-booted", () => {
  // eslint-disable-next-line no-undef
  if (!EmberENV.TESTS_FILE_LOADED) {
    throw new Error(
      'The tests file was not loaded. Make sure your tests index.html includes "assets/tests.js".'
    );
  }

  const script = document.getElementById("plugin-test-script");
  if (script && !requirejs.entries["discourse/tests/plugin-tests"]) {
    throw new Error(
      `Plugin JS payload failed to load from ${script.src}. Is the Rails server running?`
    );
  }

  const params = new URLSearchParams(window.location.search);
  const skipCore = params.get("qunit_skip_core") === "1";
  const disableAutoStart = params.get("qunit_disable_auto_start") === "1";

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

  if (QUnit.config.seed === undefined) {
    // If we're running in browser, default to random order. Otherwise, let Ember Exam
    // handle randomization.
    QUnit.config.seed = Math.random().toString(36).slice(2);
  } else {
    // Don't reorder when specifying a seed
    QUnit.config.reorder = false;
  }

  loader.loadModules();

  start({
    setupTestContainer: false,
    loadTests: false,
    startTests: !disableAutoStart,
    setupEmberOnerrorValidation: !skipCore,
    setupTestIsolationValidation: true,
  });
});

window.EmberENV.TESTS_FILE_LOADED = true;
