// discourse-skip-module

//= require env
//= require jquery.debug
//= require jquery.ui.widget
//= require ember.debug
//= require message-bus
//= require qunit/qunit/qunit
//= require ember-qunit
//= require fake_xml_http_request
//= require route-recognizer
//= require pretender/pretender
//= require locales/i18n
//= require locales/en
//= require discourse-loader

// Our base application
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

// Test helpers
//= require sinon/pkg/sinon
//= require_tree ./helpers
//= require break_string

// Finally, the tests themselves
//= require_tree ./fixtures
//= require_tree ./acceptance
//= require_tree ./integration
//= require_tree ./unit
//= require_tree ../../admin/tests/admin
//= require plugin_tests
//= require setup-tests
//= require test-shims
//= require jquery.magnific-popup.min.js

document.write(
  '<div id="ember-testing-container"><div id="ember-testing"></div></div>'
);
document.write(
  "<style>#ember-testing-container { position: absolute; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; } #ember-testing { zoom: 50%; }</style>"
);

let setupTestsLegacy = require("discourse/tests/setup-tests").setupTestsLegacy;
setupTestsLegacy(window.Discourse);
