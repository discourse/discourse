import { tracked } from "@glimmer/tracking";
import { debounce } from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { setOwner } from "@ember/application";

export default class ChatLivePanel {
  @service chat;
  @service chatApi;
  @service chatChannelsManager;
  @service chatComposerPresenceManager;
  @service chatEmojiReactionStore;
  @service router;
  @service site;
  @service appEvents;

  @tracked editingMessage = null;
  @tracked replyToMsg = null;

  linkedComponent = null;

  constructor(owner, linkedComponent) {
    setOwner(this, owner);
    this.linkedComponent = linkedComponent;
  }

  @action
  setReplyTo(messageOrId) {
    if (messageOrId) {
      this.cancelEditing();

      const message =
        typeof messageOrId === "number"
          ? this.chat.activeChannel.messagesManager.findMessage(messageOrId)
          : messageOrId;
      this.replyToMsg = message;
      this.#focusComposer();
    } else {
      this.replyToMsg = null;
    }

    this.onComposerValueChange({ replyToMsg: this.replyToMsg });
  }

  @action
  onComposerValueChange({
    value,
    uploads,
    replyToMsg,
    inProgressUploadsCount,
  }) {
    if (!this.editingMessage && !this.chat.activeChannel.isDraft) {
      if (typeof value !== "undefined") {
        this.chat.activeChannel.draft.message = value;
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
        this.chat.activeChannel.draft.uploads = uploads;
      }

      if (typeof replyToMsg !== "undefined") {
        this.chat.activeChannel.draft.replyToMsg = replyToMsg;
      }
    }

    if (!this.chat.activeChannel.isDraft) {
      this.#reportReplyingPresence(value);
    }

    this._persistDraft();
  }

  @action
  cancelEditing() {
    this.editingMessage = null;
  }

  @action
  editButtonClicked(messageId) {
    const message =
      this.chat.activeChannel.messagesManager.findMessage(messageId);
    this.editingMessage = message;

    // TODO (martin) Move scrollToLatestMessage to live panel.
    // this.scrollToLatestMessage();

    this.#focusComposer();
  }

  #focusComposer() {
    this.appEvents.trigger("chat:focus-composer");
  }

  #reportReplyingPresence(composerValue) {
    if (this.#componentDeleted) {
      return;
    }

    if (this.chat.activeChannel.isDraft) {
      return;
    }

    const replying = !this.editingMessage && !!composerValue;
    this.chatComposerPresenceManager.notifyState(
      this.chat.activeChannel.id,
      replying
    );
  }

  get #componentDeleted() {
    return this.linkedComponent._selfDeleted;
  }

  @debounce(2000)
  _persistDraft() {
    if (this.#componentDeleted) {
      return;
    }

    if (!this.chat.activeChannel.draft) {
      return;
    }

    return this.chatApi.saveDraft(
      this.chat.activeChannel.id,
      this.chat.activeChannel.draft.toJSON()
    );
  }
}
