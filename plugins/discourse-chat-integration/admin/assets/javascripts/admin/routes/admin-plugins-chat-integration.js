import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminPluginsChatIntegration extends DiscourseRoute {
  @service router;

  model() {
    return this.store.findAll("provider");
  }

  @action
  showSettings() {
    this.router.transitionTo("adminSiteSettingsCategory", "chat_integration");
  }
}
