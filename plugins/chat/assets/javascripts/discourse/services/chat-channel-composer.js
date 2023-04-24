import { tracked } from "@glimmer/tracking";
import Service, { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { getOwner } from "discourse-common/lib/get-owner";
import discourseDebounce from "discourse-common/lib/debounce";
import { cancel } from "@ember/runloop";
import I18n from "I18n";
import { isEmpty } from "@ember/utils";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service chatApi;
  @service chatComposerPresenceManager;
  @service currentUser;

  @tracked channel;
  @tracked _message;

  @action
  cancel() {
    if (this.message.editing) {
      this.reset();
    } else if (this.message.inReplyTo) {
      this.message.inReplyTo = null;
    }
  }

  @action
  reset() {
    this.message = ChatMessage.createDraftMessage(this.channel, {
      user: this.currentUser,
    });
  }

  @action
  clear() {
    this.message.message = "";
  }

  @action
  editMessage(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    this.message = message;
  }

  @action
  onCancelEditing() {
    this.reset();
  }

  @action
  replyTo(message) {
    this.chat.activeMessage = null;
    this.message.inReplyTo = message;
    this.persistDraft();
  }

  @action
  persistDraft() {
    if (this.channel.isDraft) {
      return;
    }

    this._persistHandler = discourseDebounce(
      this,
      this._debouncedPersistDraft,
      2000
    );
  }

  get pane() {
    return getOwner(this).lookup("service:chat-channel-pane");
  }

  get disabled() {
    return (
      (this.channel.isDraft && isEmpty(this.channel?.chatable?.users)) ||
      !this.chat.userCanInteractWithChat ||
      !this.channel.canModifyMessages(this.currentUser)
    );
  }

  get placeholder() {
    if (!this.channel.canModifyMessages(this.currentUser)) {
      return I18n.t(
        `chat.placeholder_new_message_disallowed.${this.channel.status}`
      );
    }

    if (this.channel.isDraft) {
      if (this.channel?.chatable?.users?.length) {
        return I18n.t("chat.placeholder_start_conversation_users", {
          commaSeparatedUsernames: this.channel.chatable.users
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
      return this.#messageRecipients(this.channel);
    }
  }

  get message() {
    return this._message;
  }

  set message(message) {
    cancel(this._persistHandler);
    this._message = message;
  }

  @action
  _debouncedPersistDraft() {
    this.chatApi.saveDraft(this.channel.id, this.message.toJSONDraft());
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
