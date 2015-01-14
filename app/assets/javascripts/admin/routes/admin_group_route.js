Discourse.AdminGroupRoute = Discourse.Route.extend({

  model: function(params) {
    var groups = this.modelFor('adminGroups'),
        group = groups.findProperty('name', params.name);

    if (!group) { return this.transitionTo('adminGroups.index'); }
    return group;
  },

  setupController: function(controller, model) {
    controller.set("model", model);
    model.findMembers();
  }

});

