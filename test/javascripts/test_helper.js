/*global document, sinon, QUnit, Logster */

//= require env

//= require ../../app/assets/javascripts/preload_store

// probe framework first
//= require probes

// Externals we need to load first
//= require jquery.debug
//= require jquery.ui.widget
//= require handlebars
//= require ember.debug
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

//= require helpers/qunit-helpers
//= require helpers/assertions

//= require helpers/init-ember-qunit
//= require_tree ./fixtures
//= require_tree ./lib
//= require_tree .
//= require plugin_tests
//= require_self
//
//= require ../../public/javascripts/jquery.magnific-popup-min.js

window.assetPath = function(url) {
  if (url.indexOf('defer') === 0) {
    return "/assets/" + url;
  }
};

// Stop the message bus so we don't get ajax calls
window.MessageBus.stop();

// Trick JSHint into allow document.write
var d = document;
d.write('<div id="ember-testing-container"><div id="ember-testing"></div></div>');
d.write('<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>');

Discourse.rootElement = '#ember-testing';
Discourse.setupForTesting();
Discourse.injectTestHelpers();
Discourse.start();

// disable logster error reporting
if (window.Logster) {
  Logster.enabled = false;
} else {
  window.Logster = { enabled: false };
}

var origDebounce = Ember.run.debounce,
    createPretendServer = require('helpers/create-pretender', null, null, false).default,
    fixtures = require('fixtures/site-fixtures', null, null, false).default,
    flushMap = require('discourse/models/store', null, null, false).flushMap,
    ScrollingDOMMethods = require('discourse/mixins/scrolling', null, null, false).ScrollingDOMMethods,
    _DiscourseURL = require('discourse/lib/url', null, null, false).default,
    server;

function dup(obj) {
  return jQuery.extend(true, {}, obj);
}

QUnit.testStart(function(ctx) {
  server = createPretendServer();

  // Allow our tests to change site settings and have them reset before the next test
  Discourse.SiteSettings = dup(Discourse.SiteSettingsOriginal);
  Discourse.BaseUri = "/";
  Discourse.BaseUrl = "localhost";
  Discourse.Session.resetCurrent();
  Discourse.User.resetCurrent();
  Discourse.Site.resetCurrent(Discourse.Site.create(dup(fixtures['site.json'].site)));

  _DiscourseURL.redirectedTo = null;
  _DiscourseURL.redirectTo = function(url) {
    _DiscourseURL.redirectedTo = url;
  };

  PreloadStore.reset();

  window.sandbox = sinon.sandbox.create();
  window.sandbox.stub(ScrollingDOMMethods, "screenNotFull");
  window.sandbox.stub(ScrollingDOMMethods, "bindOnScroll");
  window.sandbox.stub(ScrollingDOMMethods, "unbindOnScroll");

  // Don't debounce in test unless we're testing debouncing
  if (ctx.module.indexOf('debounce') === -1) {
    Ember.run.debounce = Ember.run;
  }
});

// Don't cloak in testing
Ember.CloakedCollectionView = Ember.CollectionView;

QUnit.testDone(function() {
  Ember.run.debounce = origDebounce;
  window.sandbox.restore();

  // Destroy any modals
  $('.modal-backdrop').remove();
  flushMap();

  server.shutdown();
});

// Load ES6 tests
var helpers = require("helpers/qunit-helpers");

// TODO: Replace with proper imports rather than globals
window.asyncTestDiscourse = helpers.asyncTestDiscourse;
window.controllerFor = helpers.controllerFor;
window.fixture = helpers.fixture;

Ember.keys(requirejs.entries).forEach(function(entry) {
  if ((/\-test/).test(entry)) {
    require(entry, null, null, true);
  }
});
