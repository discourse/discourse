import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import ChatModalNewMessage from "discourse/plugins/chat/discourse/components/chat/modal/new-message";

export default class ChatNewMessageRoute extends DiscourseRoute {
  @service chat;
  @service modal;
  @service router;

  beforeModel(transition) {
    const recipients = this.paramsFor(this.routeName).recipients?.split(",");

    if (!recipients) {
      transition.abort();

      if (!transition.from) {
        this.router.transitionTo("chat");
        return;
      }

      this.modal.show(ChatModalNewMessage);

      return;
    }

    this.chat.upsertDmChannel({ usernames: recipients }).then((channel) => {
      this.router.transitionTo("chat.channel", channel.title, channel.id);
    });
  }
}
