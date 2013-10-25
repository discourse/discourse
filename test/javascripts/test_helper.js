/*jshint maxlen:250 */
/*global count:true find:true document:true equal:true sinon:true */

//= require env

//= require ../../app/assets/javascripts/preload_store.js

// probe framework first
//= require ../../app/assets/javascripts/discourse/lib/probes.js

// Externals we need to load first
//= require development/jquery-2.0.3.js
//= require jquery.ui.widget.js
//= require handlebars.js
//= require development/ember.js

//= require ../../app/assets/javascripts/locales/i18n
//= require ../../app/assets/javascripts/discourse/helpers/i18n_helpers
//= require ../../app/assets/javascripts/locales/en

// Pagedown customizations
//= require ../../app/assets/javascripts/pagedown_custom.js

// The rest of the vendored JS
//= require LAB.js
//= require Markdown.Converter.js
//= require Markdown.Editor.js
//= require better_markdown.js
//= require bootbox.js
//= require bootstrap-alert.js
//= require bootstrap-button.js
//= require bootstrap-dropdown.js
//= require bootstrap-modal.js
//= require bootstrap-transition.js
//= require browser-update.js
//= require chosen.jquery.js
//= require ember-renderspeed.js
//= require favcount.js
//= require jquery.ba-replacetext.js
//= require jquery.ba-resize.min.js
//= require jquery.color.js
//= require jquery.cookie.js
//= require jquery.fileupload.js
//= require jquery.iframe-transport.js
//= require jquery.putcursoratend.js
//= require jquery.tagsinput.js
//= require lodash.js
//= require md5.js
//= require modernizr.custom.95264.js
//= require mousetrap.js
//= require rsvp.js
//= require show-html.js
//= require htmlparser.js

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
//= require_tree ./lib
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
  try {
    this.undef();
  } catch(e) {
    console.error("Discourse.Ajax called in test environment (" + arguments[0] + ")\n caller: " + e.stack.split("\n").slice(2).join("\n"));
  }
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
  Discourse.routeBuilder.call(this);
});


QUnit.testStart(function() {
  // Allow our tests to change site settings and have them reset before the next test
  Discourse.SiteSettings = jQuery.extend(true, {}, Discourse.SiteSettingsOriginal);
  Discourse.BaseUri = "/";
  Discourse.BaseUrl = "";
});

