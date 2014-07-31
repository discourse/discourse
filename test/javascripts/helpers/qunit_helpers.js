/* global asyncTest */
/* exported integration, testController, controllerFor, asyncTestDiscourse, fixture */
function integration(name, lifecycle) {
  module("Integration: " + name, {
    setup: function() {
      Ember.run(Discourse, Discourse.advanceReadiness);
      if (lifecycle && lifecycle.setup) {
        lifecycle.setup.call(this);
      }

      if (lifecycle && lifecycle.user) {
        Discourse.User.resetCurrent(Discourse.User.create(lifecycle.user));
      }
      Discourse.reset();
    },

    teardown: function() {
      if (lifecycle && lifecycle.teardown) {
        lifecycle.teardown.call(this);
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
