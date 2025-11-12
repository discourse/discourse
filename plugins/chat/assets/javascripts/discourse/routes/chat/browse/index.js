import { service } from "@ember/service";
import { defaultHomepage } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatBrowseIndexRoute extends DiscourseRoute {
  @service chat;
  @service siteSettings;
  @service router;

  beforeModel() {
    if (!this.siteSettings.enable_public_channels) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }
  }

  activate() {
    this.chat.activeChannel = null;
  }

  afterModel() {
    this.router.replaceWith("chat.browse.open");
  }
}
