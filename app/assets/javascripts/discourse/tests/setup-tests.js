import {
  resetSettings,
  currentSettings,
} from "discourse/tests/helpers/site-settings";
import { getOwner, setDefaultOwner } from "discourse-common/lib/get-owner";
import { setupURL, setupS3CDN } from "discourse-common/lib/get-url";
import { createHelperContext } from "discourse-common/lib/helpers";
import { buildResolver } from "discourse-common/resolver";
import createPretender, {
  pretenderHelpers,
  applyDefaultHandlers,
} from "discourse/tests/helpers/create-pretender";
import { flushMap } from "discourse/models/store";
import { ScrollingDOMMethods } from "discourse/mixins/scrolling";
import DiscourseURL from "discourse/lib/url";
import {
  resetSite,
  applyPretender,
} from "discourse/tests/helpers/qunit-helpers";
import PreloadStore from "discourse/lib/preload-store";
import User from "discourse/models/user";
import Session from "discourse/models/session";
import { clearAppEventsCache } from "discourse/services/app-events";
import QUnit from "qunit";
import MessageBus from "message-bus-client";
import deprecated from "discourse-common/lib/deprecated";
import sinon from "sinon";
import { setApplication, setResolver } from "@ember/test-helpers";

export default function setupTests(app, container) {
  setResolver(buildResolver("discourse").create({ namespace: app }));

  sinon.config = {
    injectIntoThis: false,
    injectInto: null,
    properties: ["spy", "stub", "mock", "clock", "sandbox"],
    useFakeTimers: true,
    useFakeServer: false,
  };

  // Stop the message bus so we don't get ajax calls
  MessageBus.stop();

  app.rootElement = "#ember-testing";
  app.setupForTesting();
  app.SiteSettings = currentSettings();
  app.start();

  // disable logster error reporting
  if (window.Logster) {
    window.Logster.enabled = false;
  } else {
    window.Logster = { enabled: false };
  }

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

  QUnit.testStart(function (ctx) {
    let settings = resetSettings();
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

      window.console.error(error);
      throw new Error(error);
    };

    server.checkPassthrough = (request) =>
      request.requestHeaders["Discourse-Script"];

    applyPretender(ctx.module, server, pretenderHelpers());

    setupURL(null, "http://localhost:3000", "");
    setupS3CDN(null, null);

    Session.resetCurrent();
    User.resetCurrent();
    let site = resetSite(settings);
    createHelperContext({
      siteSettings: settings,
      capabilities: {},
      site,
    });

    DiscourseURL.redirectedTo = null;
    DiscourseURL.redirectTo = function (url) {
      DiscourseURL.redirectedTo = url;
    };

    PreloadStore.reset();

    window.sandbox = sinon;
    window.sandbox.stub(ScrollingDOMMethods, "screenNotFull");
    window.sandbox.stub(ScrollingDOMMethods, "bindOnScroll");
    window.sandbox.stub(ScrollingDOMMethods, "unbindOnScroll");

    // Unless we ever need to test this, let's leave it off.
    $.fn.autocomplete = function () {};
  });

  QUnit.testDone(function () {
    window.sandbox.restore();

    // Destroy any modals
    $(".modal-backdrop").remove();
    flushMap();

    // ensures any event not removed is not leaking between tests
    // most likely in intialisers, other places (controller, component...)
    // should be fixed in code
    clearAppEventsCache(getOwner(this));

    MessageBus.unsubscribe("*");
    server = null;
    window.Mousetrap.reset();
  });

  // Load ES6 tests
  function getUrlParameter(name) {
    name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
    var regex = new RegExp("[\\?&]" + name + "=([^&#]*)");
    var results = regex.exec(location.search);
    return results === null
      ? ""
      : decodeURIComponent(results[1].replace(/\+/g, " "));
  }

  let skipCore = getUrlParameter("qunit_skip_core") === "1";
  let pluginPath = getUrlParameter("qunit_single_plugin")
    ? "/" + getUrlParameter("qunit_single_plugin") + "/"
    : "/plugins/";

  Object.keys(requirejs.entries).forEach(function (entry) {
    let isTest = /\-test/.test(entry);
    let regex = new RegExp(pluginPath);
    let isPlugin = regex.test(entry);

    if (isTest && (!skipCore || isPlugin)) {
      require(entry, null, null, true);
    }
  });

  // forces 0 as duration for all jquery animations
  jQuery.fx.off = true;
  setApplication(app);
  setDefaultOwner(container);
  resetSite();
}
