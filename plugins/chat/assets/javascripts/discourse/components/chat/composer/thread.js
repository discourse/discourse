import { action } from "@ember/object";
import { service } from "@ember/service";
import { debounce } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatComposer from "../../chat-composer";

export default class ChatComposerThread extends ChatComposer {
  @service("chat-channel-composer") channelComposer;
  // eslint-disable-next-line discourse/no-unused-services
  @service("chat-thread-composer") composer; // used in the parent class
  @service("chat-thread-pane") pane;
  @service currentUser;
  @service chatDraftsManager;

  context = "thread";

  composerId = "thread-composer";

  @debounce(2000)
  persistDraft() {
    this.chatDraftsManager.add(
      this.draft,
      this.args.thread.channel.id,
      this.args.thread.id
    );
  }

  @action
  destroyDraft() {
    this.chatDraftsManager.remove(
      this.args.thread.channel.id,
      this.args.thread.id
    );
  }

  @action
  resetDraft() {
    this.args.thread.resetDraft(this.currentUser);
  }

  get draft() {
    return this.args.thread.draft;
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
    return i18n("chat.placeholder_thread");
  }

  get lastMessage() {
    return this.args.thread.messagesManager.findLastMessage();
  }

  lastUserMessage(user) {
    return this.args.thread.messagesManager.findLastUserMessage(user);
  }

  handleEscape(event) {
    if (this.draft.editing) {
      event.stopPropagation();
      this.args.thread.draft = ChatMessage.createDraftMessage(
        this.args.thread.channel,
        { user: this.currentUser, thread: this.args.thread }
      );

      return;
    }

    this.pane.close().then(() => {
      this.channelComposer.focus();
    });
  }
}
