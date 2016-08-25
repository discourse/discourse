/*global document, sinon, Logster, QUnit */

//= require env
//= require jquery.debug
//= require loader
//= require jquery.debug
//= require handlebars
//= require ember.debug
//= require ember-template-compiler
//= require ember-qunit
//= require ember-shim
//= require wizard-application
//= require helpers/assertions
//= require_tree ./acceptance
//= require_tree ./models
//= require locales/en
//= require fake_xml_http_request
//= require route-recognizer
//= require pretender
//= require ./wizard-pretender

// Trick JSHint into allow document.write
var d = document;
d.write('<div id="ember-testing-container"><div id="ember-testing"></div></div>');
d.write('<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>');

if (window.Logster) {
  Logster.enabled = false;
} else {
  window.Logster = { enabled: false };
}

var createPretendServer = require('wizard/test/wizard-pretender', null, null, false).default;

var server;
QUnit.testStart(function() {
  server = createPretendServer();
});

QUnit.testDone(function() {
  server.shutdown();
});

var wizard = require('wizard/wizard').default.create({
  rootElement: '#ember-testing'
});
wizard.setupForTesting();
wizard.injectTestHelpers();
wizard.start();

Object.keys(requirejs.entries).forEach(function(entry) {
  if ((/\-test/).test(entry)) {
    require(entry, null, null, true);
  }
});
