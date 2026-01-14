import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatSearchRoute extends DiscourseRoute {
  @service chat;
  @service router;
  @service siteSettings;

  queryParams = { q: { replace: true } };

  activate() {
    this.chat.activeChannel = null;
  }

  redirect() {
    if (!this.siteSettings.chat_search_enabled) {
      this.router.transitionTo("chat");
    }
  }
}
