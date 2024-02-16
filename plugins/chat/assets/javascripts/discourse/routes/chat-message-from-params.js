import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatMessageFromParamsRoute extends DiscourseRoute {
  @service chat;
  @service router;

  beforeModel() {
    const usernames = this.paramsFor(this.routeName).username?.split(",");

    if (!usernames) {
      return this.router.transitionTo("chat");
    }

    this.chat.upsertDmChannel({ usernames }).then((channel) => {
      this.router.transitionTo("chat.channel", channel.title, channel.id);
    });
  }
}
