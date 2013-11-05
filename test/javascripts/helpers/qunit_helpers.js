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
  return klass.create({model: model, container: Discourse.__container__});
}

function controllerFor(controller, model) {
  var controller = Discourse.__container__.lookup('controller:' + controller);
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