import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { defaultHomepage } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default class ChatMessageRoute extends DiscourseRoute {
  @service chat;

  async model(params) {
    return ajax(`/chat/message/${params.messageId}.json`)
      .then((response) => {
        this.transitionTo(
          "chat.channel",
          response.chat_channel_id,
          response.chat_channel_title,
          {
            queryParams: { messageId: params.messageId },
          }
        );
      })
      .catch(() => this.replaceWith("/404"));
  }

  beforeModel() {
    if (!this.chat.userCanChat) {
      return this.transitionTo(`discovery.${defaultHomepage()}`);
    }
  }
}
