/**
  Until the fully async router is merged into Ember, it is healthy to do some extra checking
  that setupController is not passed a promise instead of the model we want.

  This mixin handles that case, and calls modelReady instead.

  @class Discourse.ModelReady
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.ModelReady = Em.Mixin.create({

  setupController: function(controller, model) {
    var route = this;
    if (model.then) {
      model.then(function (m) {
        controller.set('model', m);
        if (route.modelReady) { route.modelReady(controller, m); }
      });
    } else {
      controller.set('model', model);
      if (route.modelReady) { route.modelReady(controller, model); }
    }
  }

});


