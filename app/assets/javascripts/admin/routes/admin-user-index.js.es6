import DiscourseRoute from "discourse/routes/discourse";
import Group from "discourse/models/group";

export default DiscourseRoute.extend({
  model() {
    return this.modelFor("adminUser");
  },

  afterModel(model) {
    if (this.currentUser.admin) {
      return Group.findAll().then(groups => {
        this._availableGroups = groups.filterBy("automatic", false);
        return model;
      });
    }
  },

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.primary_group_id,
      availableGroups: this._availableGroups,
      customGroupIdsBuffer: null,
      model
    });
  }
});
