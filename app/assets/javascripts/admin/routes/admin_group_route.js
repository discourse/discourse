Discourse.AdminGroupRoute = Discourse.Route.extend({

  model: function(params) {
    var groups = this.modelFor('adminGroups'),
        group = groups.findProperty('name', params.name);

    if (!group) { return this.transitionTo('adminGroups.index'); }
    return group;
  },

  afterModel: function(model) {
    var self = this;
    return model.findMembers().then(function(members) {
      self.set('_members', members);
    });
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    controller.set('members', this.get('_members'));
  }
});

