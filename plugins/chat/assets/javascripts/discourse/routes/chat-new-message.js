import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class ChatNewMessageRoute extends DiscourseRoute {
  @service chat;
  @service router;

  beforeModel(transition) {
    const recipients = this.paramsFor(this.routeName).recipients?.split(",");

    if (!recipients) {
      transition.abort();
      return this.router.transitionTo("chat");
    }

    this.chat.upsertDmChannel({ usernames: recipients }).then((channel) => {
      this.router.transitionTo("chat.channel", channel.title, channel.id);
    });
  }
}
