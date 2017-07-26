/*global document, sinon, Logster, QUnit */

//= require env
//= require jquery.debug
//= require discourse-loader
//= require jquery.debug
//= require handlebars
//= require ember.debug
//= require ember-template-compiler
//= require ember-qunit
//= require ember-shim
//= require wizard-application
//= require wizard-vendor
//= require helpers/assertions
//= require_tree ./helpers
//= require_tree ./acceptance
//= require_tree ./models
//= require_tree ./components
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
Ember.Test.adapter = window.QUnitAdapter.create();

var createPretendServer = requirejs('wizard/test/wizard-pretender', null, null, false).default;

var server;
QUnit.testStart(function() {
  server = createPretendServer();
});

QUnit.testDone(function() {
  server.shutdown();
});


var _testApp = requirejs('wizard/test/helpers/start-app').default();
var _buildResolver = requirejs('discourse-common/resolver').buildResolver;
window.setResolver(_buildResolver('wizard').create({ namespace: _testApp }));

Object.keys(requirejs.entries).forEach(function(entry) {
  if ((/\-test/).test(entry)) {
    requirejs(entry, null, null, true);
  }
});
