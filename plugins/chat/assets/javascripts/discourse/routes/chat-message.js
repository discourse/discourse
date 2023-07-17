import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default class ChatMessageRoute extends DiscourseRoute {
  @service chat;
  @service router;

  async model(params) {
    return ajax(`/chat/message/${params.messageId}.json`)
      .then((response) => {
        this.router.transitionTo(
          "chat.channel.near-message",
          response.chat_channel_title,
          response.chat_channel_id,
          params.messageId
        );
      })
      .catch(() => this.replaceWith("/404"));
  }

  beforeModel() {
    if (!this.chat.userCanChat) {
      return this.router.transitionTo(`discovery.${defaultHomepage()}`);
    }
  }
}
