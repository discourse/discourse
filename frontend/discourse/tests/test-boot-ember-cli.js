import { start as startEmberExam } from "ember-exam/addon-test-support";
import { setupEmberOnerrorValidation } from "ember-qunit";
import * as QUnit from "qunit";
import { setup } from "qunit-dom";
import { loadAdmin, loadThemesAndPlugins } from "discourse/app";
import config from "discourse/config/environment";
import setupTests from "discourse/tests/setup-tests";

/**
 * Resolves once the styles that computed-geometry assertions depend on are in
 * place. `fonts.ready` only covers faces that were already requested, so the
 * element's computed font is requested explicitly first; a face that fails to
 * load must not block the run.
 *
 * @param {object} [options]
 * @param {FontFaceSet} [options.fonts] The font set to wait on.
 * @param {Element} [options.element] The element whose computed font is requested.
 * @returns {Promise<void>}
 */
export async function awaitVisualReadiness({
  fonts = document.fonts,
  element = document.body,
} = {}) {
  const { fontWeight, fontSize, fontFamily } = getComputedStyle(element);

  try {
    await fonts.load(`${fontWeight} ${fontSize} ${fontFamily}`);
  } catch {
    // A missing face degrades rendering; it must not abort the test run.
  }

  await fonts.ready;
}

function registeredTestCount() {
  return QUnit.config.modules.reduce(
    (count, module) => count + module.tests.length,
    0
  );
}

export async function startTests() {
  const beforeBundleTests = registeredTestCount();
  if (beforeBundleTests !== 0) {
    throw new Error("Tests registered before file selection");
  }
  await loadAdmin();
  await loadThemesAndPlugins();
  if (registeredTestCount() !== beforeBundleTests) {
    throw new Error("Test bundle registered tests outside a file loader");
  }

  const script = document.getElementById("plugin-test-script");
  if (script && !requirejs.entries["discourse/tests/plugin-tests"]) {
    throw new Error(
      `Plugin JS payload failed to load from ${script.src}. Is the Rails server running?`
    );
  }

  const params = new URLSearchParams(window.location.search);
  const target = params.get("target") || "core";
  const themeName = document.querySelector(
    "link[rel=modulepreload][data-theme-name]"
  )?.dataset.themeName;
  const hasThemeJs = !!themeName;

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
  const beforeSetupTests = registeredTestCount();
  await setupTests(config.APP);
  if (registeredTestCount() !== beforeSetupTests) {
    throw new Error("Test setup registered tests outside a file loader");
  }

  if (window.Testem && (hasThemeJs || target !== "core")) {
    window.Testem.on("test-result", (t) => {
      t.name = `${themeName || target} - ${t.name}`;
    });
  }

  if (QUnit.config.seed === undefined) {
    // If we're running in browser, default to random order. Otherwise, let Ember Exam
    // handle randomization.
    QUnit.config.seed = Math.random().toString(36).slice(2);
  } else {
    // Don't reorder when specifying a seed
    QUnit.config.reorder = false;
  }

  let availableModules = {};
  if (testingCore) {
    const rawModules = import.meta.glob(
      ["./**/*-test.{gjs,js,ts,gts}", "!./helpers/**"],
      { eager: true }
    );
    for (const [key, value] of Object.entries(rawModules)) {
      availableModules[key] = () => value;
    }
  } else {
    for (const name of Object.keys(requirejs.entries)) {
      if (!name.endsWith("-test")) {
        continue;
      }
      const testingTheme = hasThemeJs && /^discourse\/theme--?\d+\//.test(name);
      const testingPlugin =
        !hasThemeJs && name.startsWith("discourse/plugins/");
      if (testingTheme || testingPlugin) {
        const beforeRequireTests = registeredTestCount();
        const testModule = requirejs(name);
        if (registeredTestCount() !== beforeRequireTests) {
          throw new Error(
            `Test module registered tests outside a file loader: ${name}`
          );
        }
        if (typeof testModule === "function") {
          availableModules[name] = testModule;
        } else if (testModule.__discourseTestModule) {
          availableModules[name] = () => testModule;
        }
      }
    }
  }

  const baselineTests = registeredTestCount();
  window.Testem?.useCustomAdapter((socket) => {
    socket.emit("test-metadata", "framework-test-count", {
      count: baselineTests,
    });
  });
  let attributedTests = 0;
  Object.entries(availableModules).forEach(([name, load]) => {
    availableModules[name] = async () => {
      let beforeTests;
      try {
        const testModule = await load();
        beforeTests = registeredTestCount();
        if (typeof testModule.default !== "function") {
          throw new Error(`Test module cannot be selected by file: ${name}`);
        }
        const result = testModule.default();
        if (result?.then) {
          throw new Error(
            `Test file definitions must load synchronously: ${name}`
          );
        }
      } catch (error) {
        beforeTests ??= registeredTestCount();
        QUnit.module(name, () =>
          QUnit.test("loads", () => {
            throw error;
          })
        );
      }
      const count = registeredTestCount() - beforeTests;
      attributedTests += count;
      window.Testem?.useCustomAdapter((socket) => {
        socket.emit("test-metadata", "executed-test-file", { name, count });
      });
    };
  });

  QUnit.begin(() => {
    if (registeredTestCount() !== baselineTests + attributedTests) {
      throw new Error("Tests registered outside an observed file loader");
    }
  });

  await awaitVisualReadiness();

  startEmberExam({
    setupTestContainer: false,
    setupTestIsolationValidation: true,
    availableModules,
  });
}
