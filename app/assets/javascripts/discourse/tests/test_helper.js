// discourse-skip-module

//= require env
//= require jquery.debug
//= require jquery.ui.widget
//= require ember.debug
//= require message-bus
//= require qunit
//= require ember-qunit
//= require fake_xml_http_request
//= require route-recognizer
//= require pretender
//= require locales/i18n
//= require locales/en
//= require discourse-loader

// Our base application
//= require vendor
//= require discourse-shims
//= require markdown-it-bundle
//= require application
//= require admin

// These are not loaded in prod or development
// But we need them for testing handlebars templates in qunit
//= require handlebars
//= require ember-template-compiler

// Test helpers
//= require sinon
//= require_tree ./helpers
//= require break_string

//= require_tree ./fixtures

//= require ./setup-tests
//= require test-shims
//= require jquery.magnific-popup.min.js
