import DiscourseRoute from "discourse/routes/discourse";
import { defaultHomepage } from "discourse/lib/utilities";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

export default class ChatChannelByNameRoute extends DiscourseRoute {
  @service chat;

  async model(params) {
    return ajax(
      `/chat/chat_channels/${encodeURIComponent(params.channelName)}.json`
    )
      .then((response) => {
        this.transitionTo(
          "chat.channel",
          response.channel.id,
          response.channel.title
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
