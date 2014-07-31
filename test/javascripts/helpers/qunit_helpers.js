/* global asyncTest */
/* exported integration, testController, controllerFor, asyncTestDiscourse, fixture */
function integration(name, options) {
  module("Integration: " + name, {
    setup: function() {
      Ember.run(Discourse, Discourse.advanceReadiness);
      if (options) {
        if (options.setup) {
          options.setup.call(this);
        }

        if (options.user) {
          Discourse.User.resetCurrent(Discourse.User.create(options.user));
        }

        if (options.settings) {
          Discourse.SiteSettings = jQuery.extend(true, Discourse.SiteSettings, options.settings);
        }
      }
      Discourse.reset();
    },

    teardown: function() {
      if (options && options.teardown) {
        options.teardown.call(this);
      }

      Discourse.reset();
    }
  });
}

function controllerFor(controller, model) {
  controller = Discourse.__container__.lookup('controller:' + controller);
  if (model) { controller.set('model', model ); }
  return controller;
}

function asyncTestDiscourse(text, func) {
  asyncTest(text, function () {
    var self = this;
    Ember.run(function () {
      func.call(self);
    });
  });
}

function fixture(selector) {
  if (selector) {
    return $("#qunit-fixture").find(selector);
  }
  return $("#qunit-fixture");
}
