import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminGroupsRoute extends DiscourseRoute {
  queryParams = {
    order: { refreshModel: true, replace: true },
    asc: { refreshModel: true, replace: true },
    filter: { refreshModel: true },
    type: { refreshModel: true, replace: true },
    username: { refreshModel: true },
  };

  titleToken() {
    return i18n("admin.config.groups.title");
  }

  async model(params) {
    const groups = await this.store.findAll("group", params);
    return { groups };
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("groups", model.groups);
  }
}
