import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminUserIndexRoute extends DiscourseRoute {
  @service site;

  model() {
    return this.modelFor("adminUser");
  }

  titleToken() {
    return this.currentModel.username;
  }

  setupController(controller, model) {
    controller.setProperties({
      originalPrimaryGroupId: model.primary_group_id,
      availableGroups: this.site.groups.filter((group) => !group.automatic),
      customGroupIdsBuffer: model.customGroups.map((group) => group.id),
      ssoExternalEmail: null,
      ssoLastPayload: null,
      model,
    });
  }
}
