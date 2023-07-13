import ChatComposer from "../../chat-composer";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import { action } from "@ember/object";

export default class ChatComposerThread extends ChatComposer {
  @service("chat-channel-composer") channelComposer;
  @service("chat-thread-composer") composer;
  @service("chat-thread-pane") pane;
  @service currentUser;

  context = "thread";

  composerId = "thread-composer";

  @action
  reset() {
    this.composer.reset(this.args.thread);
  }

  get shouldRenderReplyingIndicator() {
    return this.args.thread;
  }

  get disabled() {
    return (
      !this.chat.userCanInteractWithChat ||
      !this.args.thread.channel.canModifyMessages(this.currentUser)
    );
  }

  get presenceChannelName() {
    const thread = this.args.thread;
    return `/chat-reply/${thread.channel.id}/thread/${thread.id}`;
  }

  get placeholder() {
    return I18n.t("chat.placeholder_thread");
  }

  lastUserMessage(user) {
    return this.args.thread.lastUserMessage(user);
  }

  handleEscape(event) {
    if (this.currentMessage.editing) {
      event.stopPropagation();
      this.composer.cancel(this.args.thread);
      return;
    }

    if (this.isFocused) {
      event.stopPropagation();
      this.composer.blur();
    } else {
      this.pane.close().then(() => {
        this.channelComposer.focus();
      });
    }
  }
}
