/* eslint-disable simple-import-sort/imports */
import Application from "../app";
import "./loader-shims";
/* eslint-enable simple-import-sort/imports */

import { getOwner } from "@ember/owner";
import {
  getSettledState,
  isSettled,
  setApplication,
  setResolver,
} from "@ember/test-helpers";
import $ from "jquery";
import MessageBus from "message-bus-client";
import QUnit from "qunit";
import sinon from "sinon";
import PreloadStore from "discourse/lib/preload-store";
import { resetSettings as resetThemeSettings } from "discourse/lib/theme-settings-store";
import { ScrollingDOMMethods } from "discourse/mixins/scrolling";
import Session from "discourse/models/session";
import User from "discourse/models/user";
import { resetCategoryCache } from "discourse/models/category";
import SiteSettingService from "discourse/services/site-settings";
import { flushMap } from "discourse/services/store";
import pretender, {
  applyDefaultHandlers,
  pretenderHelpers,
  resetPretender,
} from "discourse/tests/helpers/create-pretender";
import { setupDeprecationCounter } from "discourse/tests/helpers/deprecation-counter";
import { clearState as clearPresenceState } from "discourse/tests/helpers/presence-pretender";
import {
  applyPretender,
  exists,
  resetSite,
  testCleanup,
  testsInitialized,
  testsTornDown,
} from "discourse/tests/helpers/qunit-helpers";
import { configureRaiseOnDeprecation } from "discourse/tests/helpers/raise-on-deprecation";
import { resetSettings } from "discourse/tests/helpers/site-settings";
import { disableCloaking } from "discourse/widgets/post-stream";
import deprecated from "discourse-common/lib/deprecated";
import { setDefaultOwner } from "discourse-common/lib/get-owner";
import { setupS3CDN, setupURL } from "discourse-common/lib/get-url";
import { buildResolver } from "discourse-common/resolver";
import { loadSprites } from "../lib/svg-sprite-loader";
import * as FakerModule from "@faker-js/faker";
import { setLoadedFaker } from "discourse/lib/load-faker";

let cancelled = false;
let started = false;

function createApplication(config, settings) {
  const app = Application.create(config);

  app.injectTestHelpers();
  setApplication(app);
  setResolver(buildResolver("discourse").create({ namespace: app }));

  // Modern Ember only sets up a container when the ApplicationInstance
  // is booted. We have legacy code which relies on having access to a container
  // before boot (e.g. during pre-initializers)
  //
  // This hack sets up a container early, then stubs the container setup method
  // so that Ember will use the same container instance when it boots the ApplicationInstance
  //
  // Note that this hack is not required in production because we use the default `autoboot` flag,
  // which triggers the internal `_globalsMode` flag, which sets up an ApplicationInstance immediately when
  // an Application is initialized (via the `_buildDeprecatedInstance` method).
  //
  // In the future, we should move away from relying on the `container` before the ApplicationInstance
  // is booted, and then remove this hack.
  let container = app.__registry__.container();
  app.__container__ = container;
  setDefaultOwner(container);
  sinon
    .stub(Object.getPrototypeOf(app.__registry__), "container")
    .callsFake((opts) => {
      container.owner = opts.owner;
      container.registry = opts.owner.__registry__;
      return container;
    });

  SiteSettingService.create = () => settings;

  if (!started) {
    app.instanceInitializer({
      name: "test-helper",
      initialize: testsInitialized,
      teardown: testsTornDown,
    });

    app.start();
    started = true;
  }

  return app;
}

function setupToolbar() {
  // Most default toolbar items aren't useful for Discourse
  QUnit.config.urlConfig = QUnit.config.urlConfig.reject((c) =>
    ["noglobals", "nolint", "devmode", "dockcontainer", "nocontainer"].includes(
      c.id
    )
  );

  const pluginNames = new Set();

  document
    .querySelector("#dynamic-test-js")
    ?.content.querySelectorAll("script[data-discourse-plugin]")
    .forEach((script) => pluginNames.add(script.dataset.discoursePlugin));

  QUnit.config.urlConfig.push({
    id: "loop",
    label: "Loop until failure",
    value: "1",
  });

  QUnit.config.urlConfig.push({
    id: "target",
    label: "Target",
    value: [
      "core",
      "plugins",
      "all",
      "theme-qunit",
      "-----",
      ...Array.from(pluginNames),
    ],
  });

  QUnit.begin(() => {
    const select = document.querySelector(
      `#qunit-testrunner-toolbar [name=target]`
    );

    const testingThemeId = parseInt(
      document.querySelector("script[data-theme-id]")?.dataset.themeId,
      10
    );
    if (testingThemeId) {
      select.innerHTML = `<option selected>theme id ${testingThemeId}</option>`;
      select.disabled = true;
      return;
    }

    select.value ||= "core";
    select.querySelector("option:not([value])").remove();
    select.querySelector("option[value=-----]").disabled = true;
    select.querySelector("option[value=all]").innerText =
      "all (not recommended)";
  });

  // Abort tests when the qunit controls are clicked
  document.querySelector("#qunit").addEventListener("click", ({ target }) => {
    if (!target.closest("#qunit-testrunner-toolbar")) {
      // Outside toolbar, carry on
      return;
    }

    if (target.closest("label[for=qunit-urlconfig-hidepassed]")) {
      // This one can be toggled during tests, carry on
      return;
    }

    if (["INPUT", "SELECT", "LABEL"].includes(target.tagName)) {
      cancelled = true;
      document.querySelector("#qunit-abort-tests-button")?.click();
    }
  });
}

function reportMemoryUsageAfterTests() {
  QUnit.done(() => {
    const usageBytes = performance.memory?.usedJSHeapSize;
    let result;
    if (usageBytes) {
      result = `${(usageBytes / Math.pow(2, 30)).toFixed(3)}GB`;
    } else {
      result = "(performance.memory api unavailable)";
    }

    writeSummaryLine(`Used JS Heap Size: ${result}`);
  });
}

function writeSummaryLine(message) {
  // eslint-disable-next-line no-console
  console.log(`\n${message}\n`);
  if (window.Testem) {
    window.Testem.useCustomAdapter(function (socket) {
      socket.emit("test-metadata", "summary-line", {
        message,
      });
    });
  }
}

export default function setupTests(config) {
  disableCloaking();

  setupDeprecationCounter(QUnit);

  QUnit.config.hidepassed = true;
  QUnit.config.testTimeout = 60_000;

  sinon.config = {
    injectIntoThis: false,
    injectInto: null,
    properties: ["spy", "stub", "mock", "clock", "sandbox"],
    useFakeTimers: true,
    useFakeServer: false,
  };

  // Stop the message bus so we don't get ajax calls
  MessageBus.stop();

  // disable logster error reporting
  if (window.Logster) {
    window.Logster.enabled = false;
  } else {
    window.Logster = { enabled: false };
  }

  Object.defineProperty(window, "exists", {
    get() {
      deprecated(
        "Accessing the global function `exists` is deprecated. Import it instead.",
        {
          since: "2.6.0.beta.4",
          dropFrom: "2.6.0",
          id: "discourse.qunit.global-exists",
        }
      );
      return exists;
    },
  });

  let setupData;
  const setupDataElement = document.getElementById("data-discourse-setup");
  if (setupDataElement) {
    setupData = setupDataElement.dataset;
    setupDataElement.remove();
  }

  let app;
  QUnit.testStart(function (ctx) {
    let settings = resetSettings();
    resetThemeSettings();

    app = createApplication(config, settings);

    const cdn = setupData ? setupData.cdn : null;
    const baseUri = setupData ? setupData.baseUri : "";
    setupURL(cdn, "http://localhost:3000", baseUri, { snapshot: true });
    if (setupData && setupData.s3BaseUrl) {
      setupS3CDN(setupData.s3BaseUrl, setupData.s3Cdn, { snapshot: true });
    } else {
      setupS3CDN(null, null, { snapshot: true });
    }

    applyDefaultHandlers(pretender);

    pretender.prepareBody = function (body) {
      if (typeof body === "object") {
        return JSON.stringify(body);
      }
      return body;
    };

    if (QUnit.config.logAllRequests) {
      pretender.handledRequest = function (verb, path) {
        // eslint-disable-next-line no-console
        console.log("REQ: " + verb + " " + path);
      };
    }

    pretender.unhandledRequest = function (verb, path) {
      if (QUnit.config.logAllRequests) {
        // eslint-disable-next-line no-console
        console.log("REQ: " + verb + " " + path + " missing");
      }

      const error =
        "Unhandled request in test environment: " + path + " (" + verb + ")";

      // eslint-disable-next-line no-console
      console.error(error);
      throw new Error(error);
    };

    pretender.checkPassthrough = (request) =>
      request.requestHeaders["Discourse-Script"];

    applyPretender(ctx.module, pretender, pretenderHelpers());

    Session.resetCurrent();
    User.resetCurrent();

    PreloadStore.reset();
    resetSite();

    resetCategoryCache();

    sinon.stub(ScrollingDOMMethods, "bindOnScroll");
    sinon.stub(ScrollingDOMMethods, "unbindOnScroll");
  });

  QUnit.testDone(function () {
    testCleanup(getOwner(app), app);

    sinon.restore();
    resetPretender();
    clearPresenceState();

    document.body.removeAttribute("class");
    let html = document.documentElement;
    html.removeAttribute("class");
    html.removeAttribute("style");
    let testing = document.getElementById("ember-testing");
    testing.removeAttribute("class");
    testing.removeAttribute("style");

    const testContainer = document.getElementById("ember-testing-container");
    testContainer.scrollTop = 0;
    testContainer.scrollLeft = 0;

    flushMap();

    MessageBus.unsubscribe("*");
    localStorage.clear();
  });

  if (getUrlParameter("qunit_disable_auto_start") === "1") {
    QUnit.config.autostart = false;
  }

  if (getUrlParameter("loop")) {
    QUnit.done(({ failed }) => {
      if (failed === 0 && !cancelled) {
        window.location.reload();
      }
    });
  }

  handleLegacyParameters();

  const target = getUrlParameter("target") || "core";
  if (target === "theme-qunit") {
    window.location.href = window.location.origin + "/theme-qunit";
  }

  const hasPluginJs = !!document.querySelector("script[data-discourse-plugin]");
  const hasThemeJs = !!document.querySelector("script[data-theme-id]");

  // forces 0 as duration for all jquery animations
  $.fx.off = true;

  setupToolbar();
  reportMemoryUsageAfterTests();
  patchFailedAssertion();
  if (!window.Testem) {
    // Running in a dev server - svg sprites are available
    // Using a fake 40-char version hash will redirect to the current one
    loadSprites(
      "/svg-sprite/localhost/svg--aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.js",
      "fontawesome"
    );
  }

  setLoadedFaker(FakerModule);

  if (!hasPluginJs && !hasThemeJs) {
    configureRaiseOnDeprecation();
  }
}

function getUrlParameter(name) {
  const queryParams = new URLSearchParams(window.location.search);
  return queryParams.get(name);
}

function patchFailedAssertion() {
  const oldPushResult = QUnit.assert.pushResult;

  QUnit.assert.pushResult = function (resultInfo) {
    if (!resultInfo.result && !isSettled()) {
      const settledState = getSettledState();
      let stateString = Object.entries(settledState)
        .filter(([, value]) => value === true)
        .map(([key]) => key)
        .join(", ");

      if (settledState.pendingRequestCount > 0) {
        stateString += `, pending requests: ${settledState.pendingRequestCount}`;
      }

      // eslint-disable-next-line no-console
      console.warn(
        `ℹ️ Hint: when the assertion failed, the Ember runloop was not in a settled state. Maybe you missed an \`await\` further up the test? Or maybe you need to manually add \`await settled()\` before your assertion? (${stateString})`
      );
    }

    oldPushResult.call(this, resultInfo);
  };
}

function handleLegacyParameters() {
  for (const param of [
    "qunit_single_plugin",
    "qunit_skip_core",
    "qunit_skip_plugins",
  ]) {
    if (getUrlParameter(param)) {
      QUnit.begin(() => {
        throw new Error(
          `${param} is no longer supported. Use the 'target' parameter instead`
        );
      });
    }
  }
}
