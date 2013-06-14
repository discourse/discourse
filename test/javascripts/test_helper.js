/*jshint maxlen:250 */
/*global count:true find:true document:true */

//= require env

//= require ../../app/assets/javascripts/preload_store.js

// probe framework first
//= require ../../app/assets/javascripts/discourse/components/probes.js

// Externals we need to load first
//= require ../../app/assets/javascripts/external/jquery-1.9.1.js
//= require ../../app/assets/javascripts/external/jquery.ui.widget.js
//= require ../../app/assets/javascripts/external/handlebars-1.0.rc.4.js
//= require ../../app/assets/javascripts/external_development/ember.js
//= require ../../app/assets/javascripts/external_development/group-helper.js

//= require ../../app/assets/javascripts/locales/i18n
//= require ../../app/assets/javascripts/locales/date_locales.js
//= require ../../app/assets/javascripts/discourse/helpers/i18n_helpers
//= require ../../app/assets/javascripts/locales/en
//
// Pagedown customizations
//= require ../../app/assets/javascripts/pagedown_custom.js

// The rest of the externals
//= require_tree ../../app/assets/javascripts/external

// Stuff we need to load first
//= require main_include
//= require admin
//= require_tree ../../app/assets/javascripts/defer

//= require main_include
//= require_tree .
//= require_self

//= require_tree ./fixtures

// Trick JSHint into allow document.write
var d = document;
d.write('<div id="ember-testing-container"><div id="ember-testing"></div></div>');
d.write('<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>');

Discourse.rootElement = '#ember-testing';
Discourse.setupForTesting();
Discourse.injectTestHelpers();


Discourse.Router.map(function() {
  return Discourse.routeBuilder.call(this);
});

function exists(selector) {
  return !!count(selector);
}

function count(selector) {
  return find(selector).length;
}