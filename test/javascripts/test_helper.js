// discourse-skip-module

/*global document, sinon, QUnit, Logster */
//= require env
//= require jquery.debug
//= require jquery.ui.widget
//= require ember.debug
//= require message-bus
//= require qunit/qunit/qunit
//= require ember-qunit
//= require fake_xml_http_request
//= require route-recognizer/dist/route-recognizer
//= require pretender/pretender
//= require locales/i18n
//= require locales/en_US
//= require discourse-loader

// Stuff we need to load first
//= require vendor
//= require discourse-shims
//= require pretty-text-bundle
//= require markdown-it-bundle
//= require application
//= require admin

// These are not loaded in prod or development
// But we need them for testing handlebars templates in qunit
//= require handlebars
//= require ember-template-compiler

//= require sinon/pkg/sinon

//= require helpers/assertions

//= require break_string
//= require helpers/qunit-helpers
//= require_tree ./fixtures
//= require_tree ./lib
//= require_tree .
//= require plugin_tests
//= require_self
//
//= require jquery.magnific-popup.min.js

const buildResolver = require("discourse-common/resolver").buildResolver;
window.setResolver(buildResolver("discourse").create({ namespace: Discourse }));

sinon.config = {
  injectIntoThis: false,
  injectInto: null,
  properties: ["spy", "stub", "mock", "clock", "sandbox"],
  useFakeTimers: true,
  useFakeServer: false
};

let MessageBus = require("message-bus-client").default;

// Stop the message bus so we don't get ajax calls
MessageBus.stop();

// Trick JSHint into allow document.write
var d = document;
d.write(
  '<div id="ember-testing-container"><div id="ember-testing"></div></div>'
);
d.write(
  "<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>"
);

Discourse.rootElement = "#ember-testing";
Discourse.setupForTesting();
Discourse.injectTestHelpers();
Discourse.start();

// disable logster error reporting
if (window.Logster) {
  Logster.enabled = false;
} else {
  window.Logster = { enabled: false };
}

var createPretender = require("helpers/create-pretender", null, null, false),
  fixtures = require("fixtures/site-fixtures", null, null, false).default,
  flushMap = require("discourse/models/store", null, null, false).flushMap,
  ScrollingDOMMethods = require("discourse/mixins/scrolling", null, null, false)
    .ScrollingDOMMethods,
  _DiscourseURL = require("discourse/lib/url", null, null, false).default,
  applyPretender = require("helpers/qunit-helpers", null, null, false)
    .applyPretender,
  server,
  acceptanceModulePrefix = "Acceptance: ";

function dup(obj) {
  return jQuery.extend(true, {}, obj);
}

function resetSite(siteSettings, extras) {
  let createStore = require("helpers/create-store").default;
  let siteAttrs = $.extend({}, fixtures["site.json"].site, extras || {});
  let Site = require("discourse/models/site").default;
  siteAttrs.store = createStore();
  siteAttrs.siteSettings = siteSettings;
  Site.resetCurrent(Site.create(siteAttrs));
}

QUnit.testStart(function(ctx) {
  server = createPretender.default;
  createPretender.applyDefaultHandlers(server);
  server.handlers = [];

  server.prepareBody = function(body) {
    if (body && typeof body === "object") {
      return JSON.stringify(body);
    }
    return body;
  };

  if (QUnit.config.logAllRequests) {
    server.handledRequest = function(verb, path, request) {
      console.log("REQ: " + verb + " " + path);
    };
  }

  server.unhandledRequest = function(verb, path) {
    if (QUnit.config.logAllRequests) {
      console.log("REQ: " + verb + " " + path + " missing");
    }

    const error =
      "Unhandled request in test environment: " + path + " (" + verb + ")";
    window.console.error(error);
    throw error;
  };

  server.checkPassthrough = request =>
    request.requestHeaders["Discourse-Script"];

  if (ctx.module.startsWith(acceptanceModulePrefix)) {
    var helper = {
      parsePostData: createPretender.parsePostData,
      response: createPretender.response,
      success: createPretender.success
    };

    applyPretender(
      ctx.module.replace(acceptanceModulePrefix, ""),
      server,
      helper
    );
  }

  // Allow our tests to change site settings and have them reset before the next test
  Discourse.SiteSettings = dup(Discourse.SiteSettingsOriginal);

  let getURL = require("discourse-common/lib/get-url");
  getURL.setupURL(null, "http://localhost:3000", "");
  getURL.setupS3CDN(null, null);

  let User = require("discourse/models/user").default;
  let Session = require("discourse/models/session").default;
  Session.resetCurrent();
  User.resetCurrent();
  resetSite(Discourse.SiteSettings);

  _DiscourseURL.redirectedTo = null;
  _DiscourseURL.redirectTo = function(url) {
    _DiscourseURL.redirectedTo = url;
  };

  var ps = require("discourse/lib/preload-store").default;
  ps.reset();

  window.sandbox = sinon;
  window.sandbox.stub(ScrollingDOMMethods, "screenNotFull");
  window.sandbox.stub(ScrollingDOMMethods, "bindOnScroll");
  window.sandbox.stub(ScrollingDOMMethods, "unbindOnScroll");

  // Unless we ever need to test this, let's leave it off.
  $.fn.autocomplete = function() {};
});

QUnit.testDone(function() {
  window.sandbox.restore();

  // Destroy any modals
  $(".modal-backdrop").remove();
  flushMap();

  // ensures any event not removed is not leaking between tests
  // most likely in intialisers, other places (controller, component...)
  // should be fixed in code
  require("discourse/services/app-events").clearAppEventsCache(
    window.Discourse.__container__
  );

  MessageBus.unsubscribe("*");
  delete window.server;
  window.Mousetrap.reset();
});

// Load ES6 tests
var helpers = require("helpers/qunit-helpers");

function getUrlParameter(name) {
  name = name.replace(/[\[]/, "\\[").replace(/[\]]/, "\\]");
  var regex = new RegExp("[\\?&]" + name + "=([^&#]*)");
  var results = regex.exec(location.search);
  return results === null
    ? ""
    : decodeURIComponent(results[1].replace(/\+/g, " "));
}

var skipCore = getUrlParameter("qunit_skip_core") == "1";
var pluginPath = getUrlParameter("qunit_single_plugin")
  ? "/" + getUrlParameter("qunit_single_plugin") + "/"
  : "/plugins/";

Object.keys(requirejs.entries).forEach(function(entry) {
  var isTest = /\-test/.test(entry);
  var regex = new RegExp(pluginPath);
  var isPlugin = regex.test(entry);

  if (isTest && (!skipCore || isPlugin)) {
    require(entry, null, null, true);
  }
});

// forces 0 as duration for all jquery animations
jQuery.fx.off = true;

resetSite();
