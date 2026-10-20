import { service } from "@ember/service";
import { discoveryHomepageRoute } from "discourse/lib/homepage-router-overrides";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatBrowseIndexRoute extends DiscourseRoute {
  @service chat;
  @service siteSettings;
  @service router;

  beforeModel() {
    if (!this.siteSettings.enable_public_channels) {
      return this.router.transitionTo(discoveryHomepageRoute());
    }
  }

  activate() {
    this.chat.activeChannel = null;
  }

  afterModel() {
    this.router.replaceWith("chat.browse.open");
  }
}
