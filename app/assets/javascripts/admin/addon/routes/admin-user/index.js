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
      availableGroups: this.site.groups.filter((g) => !g.automatic),
      customGroupIdsBuffer: model.customGroups.mapBy("id"),
      ssoExternalEmail: null,
      ssoLastPayload: null,
      model,
    });
  }
}
