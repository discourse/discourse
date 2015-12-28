import Group from 'discourse/models/group';

export default Discourse.Route.extend({

  model: function(params) {
    var groups = this.modelFor('adminGroupsType');
    if (params.name === 'new') {
      return Group.create({
        automatic: false,
        visible: true
      });
    }

    var group = groups.findProperty('name', params.name);

    if (!group) { return this.transitionTo('adminGroups.index'); }

    return group;
  },

  setupController: function(controller, model) {
    controller.set("model", model);
    controller.set("model.usernames", null);
    controller.set("savingStatus", '');
    model.findMembers();
  }

});
