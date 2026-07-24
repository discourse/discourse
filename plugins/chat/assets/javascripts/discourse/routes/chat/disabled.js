import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class ChatDisabledRoute extends DiscourseRoute {
  @service chat;
  @service router;

  titleToken() {
    return i18n("chat.disabled.title");
  }

  beforeModel() {
    if (!this.chat.chatDisabledInPreferences) {
      return this.router.transitionTo("chat");
    }
  }
}
