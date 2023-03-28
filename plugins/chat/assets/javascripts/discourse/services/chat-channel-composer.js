import { debounce } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";
import Service, { inject as service } from "@ember/service";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service chatApi;
  @service chatComposerPresenceManager;

  @tracked editingMessage = null;
  @tracked replyToMsg = null;
  @tracked linkedComponent = null;

  reset() {
    this.editingMessage = null;
    this.replyToMsg = null;
  }

  get #model() {
    return this.chat.activeChannel;
  }

  setReplyTo(messageOrId) {
    if (messageOrId) {
      this.cancelEditing();

      const message =
        typeof messageOrId === "number"
          ? this.#model.messagesManager.findMessage(messageOrId)
          : messageOrId;
      this.replyToMsg = message;
      this.#focusComposer();
    } else {
      this.replyToMsg = null;
    }

    this.onComposerValueChange({ replyToMsg: this.replyToMsg });
  }

  editButtonClicked(messageId) {
    const message = this.#model.messagesManager.findMessage(messageId);
    this.editingMessage = message;

    // TODO (martin) Move scrollToLatestMessage to live panel.
    // this.scrollToLatestMessage();

    this.#focusComposer();
  }

  onComposerValueChange({
    value,
    uploads,
    replyToMsg,
    inProgressUploadsCount,
  }) {
    if (!this.#model) {
      return;
    }

    if (!this.editingMessage && !this.#model.isDraft) {
      if (typeof value !== "undefined") {
        this.#model.draft.message = value;
      }

      // only save the uploads to the draft if we are not still uploading other
      // ones, otherwise we get into a cycle where we pass the draft uploads as
      // existingUploads back to the upload component and cause in progress ones
      // to be cancelled
      if (
        typeof uploads !== "undefined" &&
        inProgressUploadsCount !== "undefined" &&
        inProgressUploadsCount === 0
      ) {
        this.#model.draft.uploads = uploads;
      }

      if (typeof replyToMsg !== "undefined") {
        this.#model.draft.replyToMsg = replyToMsg;
      }
    }

    if (!this.#model.isDraft) {
      this.#reportReplyingPresence(value);
    }

    this._persistDraft();
  }

  cancelEditing() {
    this.editingMessage = null;
  }

  registerFocusHandler(handlerFn) {
    this.focusHandler = handlerFn;
  }

  #focusComposer() {
    this.focusHandler();
  }

  #reportReplyingPresence(composerValue) {
    if (this.#componentDeleted) {
      return;
    }

    if (this.#model.isDraft) {
      return;
    }

    const replying = !this.editingMessage && !!composerValue;
    this.chatComposerPresenceManager.notifyState(this.#model.id, replying);
  }

  @debounce(2000)
  _persistDraft() {
    if (this.#componentDeleted || !this.#model) {
      return;
    }

    if (!this.#model.draft) {
      return;
    }

    return this.chatApi.saveDraft(this.#model.id, this.#model.draft.toJSON());
  }

  get #componentDeleted() {
    // note I didn't set this in the new version, not sure yet what to do with it
    // return this.linkedComponent._selfDeleted;
  }
}
