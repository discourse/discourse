import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class ChatBrowseIndexRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  afterModel() {
    if (!this.siteSettings.chat_allow_archiving_channels) {
      this.router.replaceWith("chat.browse");
    }
  }
}
