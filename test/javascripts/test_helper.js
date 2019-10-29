/*global document, sinon, QUnit, Logster */

//= require env
//= require jquery.debug
//= require jquery.ui.widget
//= require handlebars
//= require ember.debug
//= require ember-template-compiler
//= require message-bus
//= require qunit/qunit/qunit
//= require ember-qunit
//= require fake_xml_http_request
//= require route-recognizer/dist/route-recognizer
//= require pretender/pretender
//= require discourse-loader
//= require preload-store

//= require locales/i18n
//= require locales/en_US

// Stuff we need to load first
//= require vendor
//= require ember-shim
//= require pretty-text-bundle
//= require markdown-it-bundle
//= require application
//= require admin

//= require sinon/pkg/sinon

//= require helpers/assertions

//= require helpers/qunit-helpers
//= require_tree ./fixtures
//= require_tree ./lib
//= require_tree .
//= require plugin_tests
//= require_self
//
//= require jquery.magnific-popup.min.js

sinon.config = {
  injectIntoThis: false,
  injectInto: null,
  properties: ["spy", "stub", "mock", "clock", "sandbox"],
  useFakeTimers: true,
  useFakeServer: false
};

window.inTestEnv = true;

// Stop the message bus so we don't get ajax calls
window.MessageBus.stop();

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

var pretender = require("helpers/create-pretender", null, null, false),
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
  var createStore = require("helpers/create-store").default;
  var siteAttrs = $.extend({}, fixtures["site.json"].site, extras || {});
  siteAttrs.store = createStore();
  siteAttrs.siteSettings = siteSettings;
  Discourse.Site.resetCurrent(Discourse.Site.create(siteAttrs));
}

QUnit.testStart(function(ctx) {
  server = pretender.default();

  if (ctx.module.startsWith(acceptanceModulePrefix)) {
    var helper = {
      parsePostData: pretender.parsePostData,
      response: pretender.response,
      success: pretender.success
    };

    applyPretender(
      ctx.module.replace(acceptanceModulePrefix, ""),
      server,
      helper
    );
  }

  // Allow our tests to change site settings and have them reset before the next test
  Discourse.SiteSettings = dup(Discourse.SiteSettingsOriginal);
  Discourse.BaseUri = "";
  Discourse.BaseUrl = "http://localhost:3000";
  Discourse.Session.resetCurrent();
  Discourse.User.resetCurrent();
  resetSite(Discourse.SiteSettings);

  _DiscourseURL.redirectedTo = null;
  _DiscourseURL.redirectTo = function(url) {
    _DiscourseURL.redirectedTo = url;
  };

  var ps = require("preload-store").default;
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

  server.shutdown();

  window.server = null;

  // ensures any event not removed is not leaking between tests
  // most likely in intialisers, other places (controller, component...)
  // should be fixed in code
  var appEvents = window.Discourse.__container__.lookup("service:app-events");
  var events = appEvents.__proto__._events;
  Object.keys(events).forEach(function(eventKey) {
    var event = events[eventKey];
    event.forEach(function(listener) {
      appEvents.off(eventKey, listener.target, listener.fn);
    });
  });

  window.MessageBus.unsubscribe("*");
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
