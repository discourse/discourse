import { tracked } from "@glimmer/tracking";
import Service, { inject as service } from "@ember/service";
import { action } from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { getOwner } from "discourse-common/lib/get-owner";
import discourseDebounce from "discourse-common/lib/debounce";
import { cancel } from "@ember/runloop";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service chatApi;
  @service chatComposerPresenceManager;
  @service currentUser;

  @tracked editingMessage = null;
  @tracked replyToMsg = null;
  @tracked linkedComponent = null;

  @tracked _message = null;

  @action
  cancel() {
    if (this.message.editing) {
      this.message = ChatMessage.createDraftMessage(this.model, {
        user: this.currentUser,
      });
    } else if (this.message.inReplyTo) {
      this.message.inReplyTo = null;
    }
  }

  @action
  reset() {
    this.message = ChatMessage.createDraftMessage(this.model, {
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

  get pane() {
    return getOwner(this).lookup("service:chat-channel-pane");
  }

  @action
  onCancelEditing() {
    this.reset();
  }

  get channel() {
    return this.chat.activeChannel;
  }

  get message() {
    return this._message;
  }

  set message(message) {
    cancel(this._persistHandler);
    this._message = message;
    // TODO (martin) Move scrollToLatestMessage to live panel.
    // this.scrollToLatestMessage()
  }

  get model() {
    return this.chat.activeChannel;
  }

  setReplyTo(message) {
    this.chat.activeMessage = null;
    this.message.inReplyTo = message;
  }

  cancelEditing() {
    this.editingMessage = null;
  }

  registerFocusHandler(handlerFn) {
    this.focusHandler = handlerFn;
  }

  focusComposer() {
    this.focusHandler();
  }

  #reportReplyingPresence(composerValue) {
    if (this.model.isDraft) {
      return;
    }

    const replying = !this.editingMessage && !!composerValue;
    this.chatComposerPresenceManager.notifyState(this.model.id, replying);
  }

  persistDraft() {
    this._persistHandler = discourseDebounce(
      this,
      this._debouncedPersistDraft,
      2000
    );
  }

  @action
  _debouncedPersistDraft() {
    this.chatApi.saveDraft(this.model.id, this.message.toJSONDraft());
  }
}
