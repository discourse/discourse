Discourse.GroupIndexRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('group');
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('group').set('showing', 'index');
  }
});
