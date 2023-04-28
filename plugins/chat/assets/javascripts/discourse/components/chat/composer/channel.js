import ChatComposer from "../../chat-composer";
import { inject as service } from "@ember/service";
import I18n from "I18n";
import discourseDebounce from "discourse-common/lib/debounce";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { Promise } from "rsvp";

export default class ChatComposerChannel extends ChatComposer {
  @service("chat-channel-composer") composer;
  @service("chat-channel-pane") pane;

  context = "channel";

  composerId = "channel-composer";

  @action
  sendMessage(raw) {
    const message = ChatMessage.createDraftMessage(this.args.channel, {
      user: this.currentUser,
      message: raw,
    });

    this.args.onSendMessage(message);

    return Promise.resolve();
  }

  @action
  persistDraft() {
    if (this.args.channel?.isDraft) {
      return;
    }

    this._persistHandler = discourseDebounce(
      this,
      this._debouncedPersistDraft,
      2000
    );
  }

  @action
  _debouncedPersistDraft() {
    this.chatApi.saveDraft(
      this.args.channel.id,
      this.currentMessage.toJSONDraft()
    );
  }

  get placeholder() {
    if (!this.args.channel.canModifyMessages(this.currentUser)) {
      return I18n.t(
        `chat.placeholder_new_message_disallowed.${this.args.channel.status}`
      );
    }

    if (this.args.channel.isDraft) {
      if (this.args.channel?.chatable?.users?.length) {
        return I18n.t("chat.placeholder_start_conversation_users", {
          commaSeparatedUsernames: this.args.channel.chatable.users
            .mapBy("username")
            .join(I18n.t("word_connector.comma")),
        });
      } else {
        return I18n.t("chat.placeholder_start_conversation");
      }
    }

    if (!this.chat.userCanInteractWithChat) {
      return I18n.t("chat.placeholder_silenced");
    } else {
      return this.#messageRecipients(this.args.channel);
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
