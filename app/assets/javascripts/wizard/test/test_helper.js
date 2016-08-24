/*global document, sinon, QUnit, Logster */

//= require env
//= require jquery.debug
//= require loader
//= require jquery.debug
//= require handlebars
//= require ember.debug
//= require ember-template-compiler
//= require ember-qunit
//= require wizard-application
//= require helpers/assertions
//= require_tree ./acceptance

// Trick JSHint into allow document.write
var d = document;
d.write('<div id="ember-testing-container"><div id="ember-testing"></div></div>');
d.write('<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>');

if (window.Logster) {
  Logster.enabled = false;
} else {
  window.Logster = { enabled: false };
}

var wizard = require('wizard/wizard').default.create({
  rootElement: '#ember-testing'
});
wizard.setupForTesting();
wizard.injectTestHelpers();

QUnit.testDone(function() {
  wizard.reset();
});

Object.keys(requirejs.entries).forEach(function(entry) {
  if ((/\-test/).test(entry)) {
    require(entry, null, null, true);
  }
});
