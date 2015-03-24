/*jshint maxlen:250 */
/*global document, sinon, QUnit, Logster */

//= require env

//= require ../../app/assets/javascripts/preload_store

// probe framework first
//= require ../../app/assets/javascripts/discourse/lib/probes

// Externals we need to load first
//= require development/jquery-2.1.1
//= require jquery.ui.widget
//= require handlebars
//= require development/ember
//= require message-bus
//= require ember-qunit
//= require fake_xml_http_request
//= require route-recognizer
//= require pretender

//= require ../../app/assets/javascripts/locales/i18n
//= require ../../app/assets/javascripts/locales/en

// Pagedown customizations
//= require ../../app/assets/javascripts/pagedown_custom.js

//= require vendor

//= require htmlparser.js

// Stuff we need to load first
//= require main_include
//= require admin
//= require_tree ../../app/assets/javascripts/defer


//= require sinon-1.7.1
//= require sinon-qunit-1.0.0
//= require jshint

//= require helpers/qunit-helpers
//= require helpers/assertions

//= require helpers/init-ember-qunit
//= require_tree ./fixtures
//= require_tree ./lib
//= require_tree .
//= require_self
//
//= require ../../public/javascripts/jquery.magnific-popup-min.js

// sinon settings
sinon.config = {
  injectIntoThis: true,
  injectInto: null,
  properties: ["spy", "stub", "mock", "clock", "sandbox"],
  useFakeTimers: false,
  useFakeServer: false
};

window.assetPath = function() { return null; };

// Stop the message bus so we don't get ajax calls
window.MessageBus.stop();

// Trick JSHint into allow document.write
var d = document;
d.write('<div id="ember-testing-container"><div id="ember-testing"></div></div>');
d.write('<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>');

Discourse.rootElement = '#ember-testing';
Discourse.setupForTesting();
Discourse.injectTestHelpers();
Discourse.runInitializers();
Discourse.start();
Discourse.Route.mapRoutes();

// disable logster error reporting
if (window.Logster) {
  Logster.enabled = false;
} else {
  window.Logster = { enabled: false };
}

var origDebounce = Ember.run.debounce,
    createPretendServer = require('helpers/create-pretender', null, null, false).default,
    fixtures = require('fixtures/site_fixtures', null, null, false).default,
    server;

QUnit.testStart(function(ctx) {
  server = createPretendServer();

  // Allow our tests to change site settings and have them reset before the next test
  Discourse.SiteSettings = jQuery.extend(true, {}, Discourse.SiteSettingsOriginal);
  Discourse.BaseUri = "/";
  Discourse.BaseUrl = "";
  Discourse.User.resetCurrent();
  Discourse.Site.resetCurrent(Discourse.Site.create(fixtures['site.json'].site));
  PreloadStore.reset();

  window.sandbox = sinon.sandbox.create();

  window.sandbox.stub(Discourse.ScrollingDOMMethods, "bindOnScroll");
  window.sandbox.stub(Discourse.ScrollingDOMMethods, "unbindOnScroll");

  // Don't debounce in test unless we're testing debouncing
  if (ctx.module.indexOf('debounce') === -1) {
    Ember.run.debounce = Ember.run;
  }
});

QUnit.testDone(function() {
  Ember.run.debounce = origDebounce;
  window.sandbox.restore();

  // Destroy any modals
  $('.modal-backdrop').remove();

  server.shutdown();
});

// Load ES6 tests
var helpers = require("helpers/qunit-helpers");

// TODO: Replace with proper imports rather than globals
window.asyncTestDiscourse = helpers.asyncTestDiscourse;
window.controllerFor = helpers.controllerFor;
window.fixture = helpers.fixture;
window.integration = helpers.integration;


Ember.keys(requirejs.entries).forEach(function(entry) {
  if ((/\-test/).test(entry)) {
    require(entry, null, null, true);
  }
});
