import { debounce } from "discourse-common/utils/decorators";
import { setOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class ChatComposerManager {
  @service chat;
  @service chatApi;
  @service chatComposerPresenceManager;

  @tracked editingMessage = null;
  @tracked replyToMsg = null;

  constructor(owner, primaryModel, linkedComponent) {
    setOwner(this, owner);
    this.primaryModel = primaryModel;
    this.linkedComponent = linkedComponent;
  }

  reset() {
    this.editingMessage = null;
    this.replyToMsg = null;
  }

  setReplyTo(messageOrId) {
    if (messageOrId) {
      this.cancelEditing();

      const message =
        typeof messageOrId === "number"
          ? this.primaryModel.messagesManager.findMessage(messageOrId)
          : messageOrId;
      this.replyToMsg = message;
      this.#focusComposer();
    } else {
      this.replyToMsg = null;
    }

    this.onComposerValueChange({ replyToMsg: this.replyToMsg });
  }

  editButtonClicked(messageId) {
    const message = this.primaryModel.messagesManager.findMessage(messageId);
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
    if (!this.editingMessage && !this.primaryModel.isDraft) {
      if (typeof value !== "undefined") {
        this.primaryModel.draft.message = value;
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
        this.primaryModel.draft.uploads = uploads;
      }

      if (typeof replyToMsg !== "undefined") {
        this.primaryModel.draft.replyToMsg = replyToMsg;
      }
    }

    if (!this.primaryModel.isDraft) {
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

    if (this.primaryModel.isDraft) {
      return;
    }

    const replying = !this.editingMessage && !!composerValue;
    this.chatComposerPresenceManager.notifyState(
      this.primaryModel.id,
      replying
    );
  }

  @debounce(2000)
  _persistDraft() {
    if (this.#componentDeleted) {
      return;
    }

    if (!this.primaryModel.draft) {
      return;
    }

    return this.chatApi.saveDraft(
      this.primaryModel.id,
      this.primaryModel.draft.toJSON()
    );
  }

  get #componentDeleted() {
    return this.linkedComponent._selfDeleted;
  }
}
