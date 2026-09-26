import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";
import SiteService from "discourse/services/site";

export default class AdminUserIndexRoute extends DiscourseRoute {
  @service(() => SiteService) site;

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
