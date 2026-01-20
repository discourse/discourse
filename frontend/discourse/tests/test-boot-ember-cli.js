import { start as startEmberExam } from "ember-exam/addon-test-support";
import { setupEmberOnerrorValidation } from "ember-qunit";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";
import { loadAdmin, loadThemes } from "discourse/app";
import config from "discourse/config/environment";
import setupTests from "discourse/tests/setup-tests";

export async function startTests() {
  await loadAdmin();
  await loadThemes();

  // if (!window.EmberENV.TESTS_FILE_LOADED) {
  //   throw new Error(
  //     'The tests file was not loaded. Make sure your tests index.html includes "assets/tests.js".'
  //   );
  // }

  const script = document.getElementById("plugin-test-script");
  if (script && !requirejs.entries["discourse/tests/plugin-tests"]) {
    throw new Error(
      `Plugin JS payload failed to load from ${script.src}. Is the Rails server running?`
    );
  }

  const params = new URLSearchParams(window.location.search);
  const target = params.get("target") || "core";
  const hasThemeJs = !!document.querySelector(
    "link[rel=modulepreload][data-theme-id]"
  );

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

  const testingCore = !hasThemeJs && target === "core";
  if (testingCore) {
    setupEmberOnerrorValidation();
  }

  setup(QUnit.assert);
  setupTests(config.APP);

  if (QUnit.config.seed === undefined) {
    // If we're running in browser, default to random order. Otherwise, let Ember Exam
    // handle randomization.
    QUnit.config.seed = Math.random().toString(36).slice(2);
  } else {
    // Don't reorder when specifying a seed
    QUnit.config.reorder = false;
  }

  let availableModules;
  if (!hasThemeJs) {
    availableModules = import.meta.glob("./**/*-test.{gjs,js}");
  }

  startEmberExam({
    setupTestContainer: false,
    setupEmberOnerrorValidation: testingCore,
    setupTestIsolationValidation: true,
    availableModules,
  });
}

// window.EmberENV.TESTS_FILE_LOADED = true;
