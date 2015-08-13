export default Discourse.Route.extend({

  model: function(params) {
    var groups = this.modelFor('adminGroupsType'),
        group = groups.findProperty('name', params.name);

    if (!group) { return this.transitionTo('adminGroups.index'); }

    return group;
  },

  setupController: function(controller, model) {
    controller.set("model", model);
    controller.set("model.usernames", null);
    model.findMembers();
  }

});
