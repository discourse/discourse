import Group from 'discourse/models/group';

export default Discourse.Route.extend({

  model(params) {
    if (params.name === 'new') {
      return Group.create({ automatic: false, visible: true });
    }

    const group = this.modelFor('adminGroupsType').findBy('name', params.name);

    if (!group) { return this.transitionTo('adminGroups.index'); }

    return group;
  },

  setupController(controller, model) {
    controller.set("model", model);
    controller.set("model.usernames", null);
    controller.set("savingStatus", "");
    model.findMembers();
  }

});
