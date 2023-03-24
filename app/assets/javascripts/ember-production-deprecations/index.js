"use strict";

/**
 * Ember's deprecation and registerDeprecationHandler APIs are stripped from production
 * builds via the DEBUG flag. This file provides a minimal reimplementation of them
 * to be used in production.
 *
 * Designed to be used alongside our fork of babel-plugin-debug-macros, which maintains
 * deprecate calls in production builds. This fork is introduced via a custom yarn resolution
 * in app/assets/javascripts/package.json.
 *
 * https://github.com/discourse/babel-plugin-debug-macros/commit/d179d613bf
 */
module.exports = {
  name: require("./package").name,

  included() {
    this._super.included.apply(this, arguments);
    this.app.import("vendor/ember-production-deprecations/deprecate-shim.js");
  },

  isDevelopingAddon() {
    return true;
  },
};
