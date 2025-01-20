import { service } from "@ember/service";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUserIndexRoute extends DiscourseRoute {
  @service siteSettings;

  model() {
    return this.modelFor("adminUser");
  }

  titleToken() {
    return this.currentModel.username;
  }

  async afterModel() {
    if (this.currentUser.admin) {
      const groups = await Group.findAll();
      this._availableGroups = groups.filterBy("automatic", false);
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
