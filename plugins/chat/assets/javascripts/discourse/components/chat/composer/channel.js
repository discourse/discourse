import ChatComposer from "../../chat-composer";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import discourseDebounce from "discourse-common/lib/debounce";
import { action } from "@ember/object";

export default class ChatComposerChannel extends ChatComposer {
  @service("chat-channel-composer") composer;
  @service("chat-channel-pane") pane;
  @service chatDraftsManager;
  @service currentUser;

  context = "channel";

  composerId = "channel-composer";

  get shouldRenderReplyingIndicator() {
    return this.args.channel;
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

  @action
  reset() {
    this.composer.reset(this.args.channel);
  }

  @action
  persistDraft() {
    this.chatDraftsManager.add(this.currentMessage);

    this._persistHandler = discourseDebounce(
      this,
      this._debouncedPersistDraft,
      this.args.channel.id,
      this.currentMessage.toJSONDraft(),
      2000
    );
  }

  @action
  _debouncedPersistDraft(channelId, jsonDraft) {
    this.chatApi.saveDraft(channelId, jsonDraft).then(() => {
      if (this.currentMessage) {
        this.currentMessage.draftSaved = true;
      }
    });
  }

  get lastMessage() {
    return this.args.channel.lastMessage;
  }

  lastUserMessage(user) {
    return this.args.channel.lastUserMessage(user);
  }

  get placeholder() {
    if (!this.args.channel.canModifyMessages(this.currentUser)) {
      return I18n.t(
        `chat.placeholder_new_message_disallowed.${this.args.channel.status}`
      );
    }

    if (!this.chat.userCanInteractWithChat) {
      return I18n.t("chat.placeholder_silenced");
    } else {
      return this.#messageRecipients(this.args.channel);
    }
  }

  handleEscape(event) {
    event.stopPropagation();

    if (this.currentMessage?.inReplyTo) {
      this.reset();
    } else if (this.currentMessage?.editing) {
      this.composer.cancel(this.args.channel);
    } else {
      event.target.blur();
    }
  }

  #messageRecipients(channel) {
    if (channel.isDirectMessageChannel) {
      const directMessageRecipients = channel.chatable.users;
      if (
        directMessageRecipients.length === 1 &&
        directMessageRecipients[0].id === this.currentUser.id
      ) {
        return I18n.t("chat.placeholder_self");
      }

      return I18n.t("chat.placeholder_users", {
        commaSeparatedNames: directMessageRecipients
          .map((u) => u.name || `@${u.username}`)
          .join(I18n.t("word_connector.comma")),
      });
    } else {
      return I18n.t("chat.placeholder_channel", {
        channelName: `#${channel.title}`,
      });
    }
  }
}
