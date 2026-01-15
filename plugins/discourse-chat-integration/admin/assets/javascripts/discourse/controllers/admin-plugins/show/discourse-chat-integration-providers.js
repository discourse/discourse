import { action } from "@ember/object";
import { service } from "@ember/service";
import Controller from "@ember/controller";

export default class DiscourseChatIntegrationProviders extends Controller {
  @service router;

  @action
  showSettings() {
    this.router.transitionTo("adminSiteSettingsCategory", "chat_integration");
  }
}
