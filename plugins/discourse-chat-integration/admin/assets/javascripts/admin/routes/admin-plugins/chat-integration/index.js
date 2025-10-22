import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsChatIntegrationIndex extends DiscourseRoute {
  @service router;

  afterModel(model) {
    if (model.totalRows > 0) {
      this.router.transitionTo(
        "adminPlugins.chat-integration.provider",
        model.get("firstObject").name
      );
    }
  }
}
