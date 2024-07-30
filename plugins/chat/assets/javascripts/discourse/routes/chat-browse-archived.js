import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatBrowseIndexRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  afterModel() {
    if (!this.siteSettings.chat_allow_archiving_channels) {
      this.router.replaceWith("chat.browse");
    }
  }
}
