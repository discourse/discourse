export default Discourse.Route.extend({

  model: function(params) {
    var groups = this.modelFor('adminGroupsType'),
        group = groups.findProperty('name', params.name);

    if (!group) { return this.transitionTo('adminGroups.index'); }

    return group;
  },

  setupController: function(controller, model) {
    controller.set("model", model);
    // clear the user selector
    controller.set("usernames", null);
    // load the members of the group
    model.findMembers();
  }

});
