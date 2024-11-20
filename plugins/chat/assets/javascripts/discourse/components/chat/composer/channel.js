import { action } from "@ember/object";
import { service } from "@ember/service";
import { debounce } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import ChatComposer from "../../chat-composer";

export default class ChatComposerChannel extends ChatComposer {
  @service("chat-channel-composer") composer;
  @service("chat-channel-pane") pane;
  @service currentUser;
  @service chatDraftsManager;

  context = "channel";

  composerId = "channel-composer";

  @debounce(2000)
  persistDraft() {
    this.chatDraftsManager.add(this.draft, this.args.channel.id);
  }

  @action
  destroyDraft() {
    this.chatDraftsManager.remove(this.args.channel.id);
  }

  @action
  resetDraft() {
    this.args.channel.resetDraft(this.currentUser);
  }

  get draft() {
    return this.args.channel.draft;
  }

  get presenceChannelName() {
    const channel = this.args.channel;
    return `/chat-reply/${channel.id}`;
  }

  get disabled() {
    return (
      !this.chat.userCanInteractWithChat ||
      !this.args.channel.canModifyMessages(this.currentUser)
    );
  }

  get lastMessage() {
    return this.args.channel.lastMessage;
  }

  lastUserMessage(user) {
    return this.args.channel.messagesManager.findLastUserMessage(user);
  }

  get placeholder() {
    if (!this.args.channel.canModifyMessages(this.currentUser)) {
      return i18n(
        `chat.placeholder_new_message_disallowed.${this.args.channel.status}`
      );
    }

    if (!this.chat.userCanInteractWithChat) {
      return i18n("chat.placeholder_silenced");
    } else {
      return this.#messageRecipients(this.args.channel);
    }
  }

  handleEscape(event) {
    event.stopPropagation();

    if (this.draft?.inReplyTo) {
      this.draft.inReplyTo = null;
    } else if (this.draft?.editing) {
      this.args.channel.resetDraft(this.currentUser);
    } else {
      event.target.blur();
    }
  }

  #messageRecipients(channel) {
    if (channel.isDirectMessageChannel) {
      if (channel.chatable.group) {
        return i18n("chat.placeholder_group");
      } else {
        const directMessageRecipients = channel.chatable.users;
        if (
          directMessageRecipients.length === 1 &&
          directMessageRecipients[0].id === this.currentUser.id
        ) {
          return i18n("chat.placeholder_self");
        }

        return i18n("chat.placeholder_users", {
          commaSeparatedNames: directMessageRecipients
            .map((u) => u.name || `@${u.username}`)
            .join(i18n("word_connector.comma")),
        });
      }
    } else {
      return i18n("chat.placeholder_channel", {
        channelName: `#${channel.title}`,
      });
    }
  }
}
