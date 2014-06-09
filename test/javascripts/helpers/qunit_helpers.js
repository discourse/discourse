/* global asyncTest, requirejs, require */
/* exported integration, testController, controllerFor, asyncTestDiscourse, fixture */
function integration(name, lifecycle) {
  module("Integration: " + name, {
    setup: function() {
      sinon.stub(Discourse.ScrollingDOMMethods, "bindOnScroll");
      sinon.stub(Discourse.ScrollingDOMMethods, "unbindOnScroll");
      Ember.run(Discourse, Discourse.advanceReadiness);

      if (lifecycle && lifecycle.setup) {
        lifecycle.setup.call(this);
      }
    },

    teardown: function() {
      if (lifecycle && lifecycle.teardown) {
        lifecycle.teardown.call(this);
      }

      Discourse.reset();
      Discourse.ScrollingDOMMethods.bindOnScroll.restore();
      Discourse.ScrollingDOMMethods.unbindOnScroll.restore();
    }
  });
}

function testController(klass, model) {
  // HAX until we get ES6 everywhere:
  if (typeof klass === "string") {
    var moduleName = 'discourse/controllers/' + klass,
        module = requirejs.entries[moduleName];
    if (module) {
      klass = require(moduleName, null, null, true).default;
    }
  }

  return klass.create({model: model, container: Discourse.__container__});
}

function controllerFor(controller, model) {
  controller = Discourse.__container__.lookup('controller:' + controller);
  if (model) { controller.set('model', model ); }
  return controller;
}

function viewClassFor(name) {
  return Discourse.__container__.lookupFactory('view:' + name);
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
