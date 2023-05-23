import { tracked } from "@glimmer/tracking";
import Service, { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatComposer extends Service {
  @service chat;
  @service currentUser;

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
  reset(channel) {
    this.message = ChatMessage.createDraftMessage(channel, {
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

  get message() {
    return this._message;
  }

  set message(message) {
    this._message = message;
  }
}
