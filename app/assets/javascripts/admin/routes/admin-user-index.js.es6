import Group from "discourse/models/group";

export default Discourse.Route.extend({
  model() {
    return this.modelFor("adminUser");
  },

  afterModel(model) {
    if (this.currentUser.get("admin")) {
      const self = this;
      return Group.findAll().then(function(groups) {
        self._availableGroups = groups.filterBy("automatic", false);
        return model;
      });
    }
  },

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.get("primary_group_id"),
      availableGroups: this._availableGroups,
      model
    });
  }
});
