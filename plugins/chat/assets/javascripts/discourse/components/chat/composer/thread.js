import ChatComposer from "../../chat-composer";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { Promise } from "rsvp";
import { action } from "@ember/object";

export default class ChatComposerThread extends ChatComposer {
  @service("chat-channel-thread-composer") composer;
  @service("chat-channel-thread-pane") pane;

  context = "thread";

  composerId = "thread-composer";

  @action
  sendMessage(raw) {
    const message = ChatMessage.createDraftMessage(this.args.channel, {
      user: this.currentUser,
      message: raw,
      thread_id: this.args.channel.activeThread.id,
    });

    this.args.onSendMessage(message);

    return Promise.resolve();
  }

  get placeholder() {
    return I18n.t("chat.placeholder_thread");
  }
}
