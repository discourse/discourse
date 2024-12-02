import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUserIndexRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminUser");
  }

  titleToken() {
    return this.currentModel.username;
  }

  afterModel(model) {
    if (this.currentUser.admin) {
      return Group.findAll().then((groups) => {
        this._availableGroups = groups.filterBy("automatic", false);
        return model;
      });
    }
  }

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.primary_group_id,
      availableGroups: this._availableGroups,
      customGroupIdsBuffer: model.customGroups.mapBy("id"),
      ssoExternalEmail: null,
      ssoLastPayload: null,
      model,
    });
  }
}
