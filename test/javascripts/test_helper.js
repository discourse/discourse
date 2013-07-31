/*jshint maxlen:250 */
/*global count:true find:true document:true equal:true sinon:true */

//= require env

//= require ../../app/assets/javascripts/preload_store.js

// probe framework first
//= require ../../app/assets/javascripts/discourse/components/probes.js

// Externals we need to load first
//= require ../../app/assets/javascripts/external_development/jquery-2.0.3.js
//= require ../../app/assets/javascripts/external/jquery.ui.widget.js
//= require ../../app/assets/javascripts/external/handlebars.js
//= require ../../app/assets/javascripts/external_development/ember.js
//= require ../../app/assets/javascripts/external_development/group-helper.js

//= require ../../app/assets/javascripts/locales/i18n
//= require ../../app/assets/javascripts/discourse/helpers/i18n_helpers
//= require ../../app/assets/javascripts/locales/en

// Pagedown customizations
//= require ../../app/assets/javascripts/pagedown_custom.js

// The rest of the externals
//= require_tree ../../app/assets/javascripts/external

// Stuff we need to load first
//= require main_include
//= require admin
//= require_tree ../../app/assets/javascripts/defer


//= require sinon-1.7.1
//= require sinon-qunit-1.0.0
//= require jshint

//= require helpers/qunit_helpers
//= require helpers/assertions

//= require_tree ./fixtures
//= require_tree .
//= require_self
//= require jshint_all

// sinon settings
sinon.config = {
  injectIntoThis: true,
  injectInto: null,
  properties: ["spy", "stub", "mock", "clock", "sandbox"],
  useFakeTimers: false,
  useFakeServer: false
};

window.assetPath = function() { return null; };

var oldAjax = $.ajax;
$.ajax = function() {
  console.error("Discourse.Ajax called in test environment (" + arguments[0] + ")");
  return oldAjax.apply(this, arguments);
};

// Trick JSHint into allow document.write
var d = document;
d.write('<div id="qunit-scratch" style="display:none"></div>');
d.write('<div id="ember-testing-container"><div id="ember-testing"></div></div>');
d.write('<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>');

Discourse.rootElement = '#ember-testing';
Discourse.setupForTesting();
Discourse.injectTestHelpers();
Discourse.bindDOMEvents();

Discourse.Router.map(function() {
  return Discourse.routeBuilder.call(this);
});


QUnit.testStart(function() {
  // Allow our tests to change site settings and have them reset before the next test
  Discourse.SiteSettings = jQuery.extend(true, {}, Discourse.SiteSettingsOriginal);
  Discourse.BaseUri = "/";
  Discourse.BaseUrl = "";
});

