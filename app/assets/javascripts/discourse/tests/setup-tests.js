import {
  applyPretender,
  exists,
  resetSite,
} from "discourse/tests/helpers/qunit-helpers";
import createPretender, {
  applyDefaultHandlers,
  pretenderHelpers,
} from "discourse/tests/helpers/create-pretender";
import {
  currentSettings,
  resetSettings,
} from "discourse/tests/helpers/site-settings";
import { getOwner, setDefaultOwner } from "discourse-common/lib/get-owner";
import { setApplication, setResolver } from "@ember/test-helpers";
import { setupS3CDN, setupURL } from "discourse-common/lib/get-url";
import Application from "../app";
import MessageBus from "message-bus-client";
import PreloadStore from "discourse/lib/preload-store";
import { resetSettings as resetThemeSettings } from "discourse/lib/theme-settings-store";
import QUnit from "qunit";
import { ScrollingDOMMethods } from "discourse/mixins/scrolling";
import Session from "discourse/models/session";
import User from "discourse/models/user";
import bootbox from "bootbox";
import { buildResolver } from "discourse-common/resolver";
import { clearAppEventsCache } from "discourse/services/app-events";
import { createHelperContext } from "discourse-common/lib/helpers";
import deprecated from "discourse-common/lib/deprecated";
import { flushMap } from "discourse/models/store";
import { registerObjects } from "discourse/pre-initializers/inject-discourse-objects";
import { setupApplicationTest } from "ember-qunit";
import sinon from "sinon";

const Plugin = $.fn.modal;
const Modal = Plugin.Constructor;

function AcceptanceModal(option, _relatedTarget) {
  return this.each(function () {
    let $this = $(this);
    let data = $this.data("bs.modal");
    let options = $.extend(
      {},
      Modal.DEFAULTS,
      $this.data(),
      typeof option === "object" && option
    );

    if (!data) {
      $this.data("bs.modal", (data = new Modal(this, options)));
    }
    data.$body = $("#ember-testing");

    if (typeof option === "string") {
      data[option](_relatedTarget);
    } else if (options.show) {
      data.show(_relatedTarget);
    }
  });
}

let app;
let started = false;

function createApplication(config, settings) {
  app = Application.create(config);
  setApplication(app);
  setResolver(buildResolver("discourse").create({ namespace: app }));

  let container = app.__registry__.container();
  app.__container__ = container;
  setDefaultOwner(container);

  if (!started) {
    app.start();
    started = true;
  }

  app.SiteSettings = settings;
  registerObjects(container, app);
  return app;
}

function setupTestsCommon(application, container, config) {
  QUnit.config.hidepassed = true;

  // Let's customize QUnit options a bit
  QUnit.config.urlConfig = QUnit.config.urlConfig.filter(
    (c) => ["dockcontainer", "nocontainer"].indexOf(c.id) === -1
  );

  application.rootElement = "#ember-testing";
  application.setupForTesting();
  application.injectTestHelpers();

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

  $.fn.modal = AcceptanceModal;

  let server;

  Object.defineProperty(window, "server", {
    get() {
      deprecated(
        "Accessing the global variable `server` is deprecated. Use a `pretend()` method instead.",
        {
          since: "2.6.0.beta.3",
          dropFrom: "2.6.0",
        }
      );
      return server;
    },
  });
  Object.defineProperty(window, "sandbox", {
    get() {
      deprecated(
        "Accessing the global variable `sandbox` is deprecated. Import `sinon` instead",
        {
          since: "2.6.0.beta.4",
          dropFrom: "2.6.0",
        }
      );
      return sinon;
    },
  });
  Object.defineProperty(window, "exists", {
    get() {
      deprecated(
        "Accessing the global function `exists` is deprecated. Import it instead.",
        {
          since: "2.6.0.beta.4",
          dropFrom: "2.6.0",
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
  QUnit.testStart(function (ctx) {
    bootbox.$body = $("#ember-testing");
    let settings = resetSettings();
    resetThemeSettings();

    if (config) {
      // Ember CLI testing environment
      app = createApplication(config, settings);
    }

    const cdn = setupData ? setupData.cdn : null;
    const baseUri = setupData ? setupData.baseUri : "";
    setupURL(cdn, "http://localhost:3000", baseUri);
    if (setupData && setupData.s3BaseUrl) {
      setupS3CDN(setupData.s3BaseUrl, setupData.s3Cdn);
    } else {
      setupS3CDN(null, null);
    }

    server = createPretender;
    server.handlers = [];
    applyDefaultHandlers(server);

    server.prepareBody = function (body) {
      if (body && typeof body === "object") {
        return JSON.stringify(body);
      }
      return body;
    };

    if (QUnit.config.logAllRequests) {
      server.handledRequest = function (verb, path) {
        // eslint-disable-next-line no-console
        console.log("REQ: " + verb + " " + path);
      };
    }

    server.unhandledRequest = function (verb, path) {
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

    server.checkPassthrough = (request) =>
      request.requestHeaders["Discourse-Script"];

    applyPretender(ctx.module, server, pretenderHelpers());

    Session.resetCurrent();
    if (setupData) {
      const session = Session.current();
      session.markdownItURL = setupData.markdownItUrl;
      session.highlightJsPath = setupData.highlightJsPath;
    }
    User.resetCurrent();
    let site = resetSite(settings);
    createHelperContext({
      siteSettings: settings,
      capabilities: {},
      site,
    });

    PreloadStore.reset();

    sinon.stub(ScrollingDOMMethods, "screenNotFull");
    sinon.stub(ScrollingDOMMethods, "bindOnScroll");
    sinon.stub(ScrollingDOMMethods, "unbindOnScroll");

    // Unless we ever need to test this, let's leave it off.
    $.fn.autocomplete = function () {};
  });

  QUnit.testDone(function () {
    sinon.restore();

    // Destroy any modals
    $(".modal-backdrop").remove();
    flushMap();

    if (!setupApplicationTest) {
      // ensures any event not removed is not leaking between tests
      // most likely in initializers, other places (controller, component...)
      // should be fixed in code
      clearAppEventsCache(getOwner(this));
    }

    MessageBus.unsubscribe("*");
    server = null;
  });

  // Load ES6 tests
  function getUrlParameter(name) {
    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
    let regex = new RegExp("[\\?&]" + name + "=([^&#]*)");
    let results = regex.exec(location.search);
    return results === null
      ? ""
      : decodeURIComponent(results[1].replace(/\+/g, " "));
  }

  let skipCore = getUrlParameter("qunit_skip_core") === "1";
  let pluginPath = getUrlParameter("qunit_single_plugin")
    ? "/" + getUrlParameter("qunit_single_plugin") + "/"
    : "/plugins/";

  if (getUrlParameter("qunit_disable_auto_start") === "1") {
    QUnit.config.autostart = false;
  }

  Object.keys(requirejs.entries).forEach(function (entry) {
    let isTest = /\-test/.test(entry);
    let regex = new RegExp(pluginPath);
    let isPlugin = regex.test(entry);

    if (!isTest) {
      return;
    }

    if (!skipCore || isPlugin) {
      require(entry, null, null, true);
    }
  });

  // forces 0 as duration for all jquery animations
  jQuery.fx.off = true;

  setApplication(application);
  setDefaultOwner(application.__container__);
  resetSite();
}

export function setupTestsLegacy(application) {
  app = application;
  setResolver(buildResolver("discourse").create({ namespace: app }));
  setupTestsCommon(application, app.__container__);

  app.SiteSettings = currentSettings();
  app.start();
}

export default function setupTests(config) {
  let settings = resetSettings();
  app = createApplication(config, settings);
  setupTestsCommon(app, app.__container__, config);
}
