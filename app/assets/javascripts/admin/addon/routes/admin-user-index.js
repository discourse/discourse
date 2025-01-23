import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import UserExport from "admin/models/user-export";

export default class AdminUserIndexRoute extends DiscourseRoute {
  model() {
    return this.modelFor("adminUser");
  }

  titleToken() {
    return this.currentModel.username;
  }

  async afterModel(model) {
    if (this.currentUser.admin) {
      const groups = await Group.findAll();
      this._availableGroups = groups.filterBy("automatic", false);

      this._userExport = UserExport.create(model.latest_export?.user_export);
    }
  }

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.primary_group_id,
      availableGroups: this._availableGroups,
      userExport: this._userExport,
      customGroupIdsBuffer: model.customGroups.mapBy("id"),
      ssoExternalEmail: null,
      ssoLastPayload: null,
      model,
    });
  }
}
