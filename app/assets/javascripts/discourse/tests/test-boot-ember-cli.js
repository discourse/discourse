import loadEmberExam from "ember-exam/test-support/load";
import { setupEmberOnerrorValidation, start } from "ember-qunit";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";
import setupTests from "discourse/tests/setup-tests";
import config from "../config/environment";

document.addEventListener("discourse-init", () => {
  if (!window.EmberENV.TESTS_FILE_LOADED) {
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
  const target = params.get("target") || "core";
  const testingTheme = !!document.querySelector("script[data-theme-id]");
  const disableAutoStart = params.get("qunit_disable_auto_start") === "1";
  const hasThemeJs = !!document.querySelector("script[data-theme-id]");

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

  const testingCore = !testingTheme && target === "core";
  if (testingCore) {
    setupEmberOnerrorValidation();
  }

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

  loader.shouldLoadModule = function (name) {
    if (!/\-test/.test(name)) {
      return false;
    }

    const isPlugin = name.match(/\/plugins\//);
    const isTheme = name.match(/\/theme-\d+\//);
    const isCore = !isPlugin && !isTheme;
    const pluginName = name.match(/\/plugins\/([\w-]+)\//)?.[1];

    const loadCore = target === "core" || target === "all";
    const loadAllPlugins = target === "plugins" || target === "all";

    if (hasThemeJs) {
      return isTheme;
    } else if (isCore && !loadCore) {
      return false;
    } else if (isPlugin && !(loadAllPlugins || pluginName === target)) {
      return false;
    }

    return true;
  };
  loader.loadModules();

  start({
    setupTestContainer: false,
    startTests: !disableAutoStart,
    setupEmberOnerrorValidation: testingCore,
    setupTestIsolationValidation: true,
  });
});

window.EmberENV.TESTS_FILE_LOADED = true;
