import { tracked } from "@glimmer/tracking";
import { getOwner } from "discourse-common/lib/get-owner";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { setOwner } from "@ember/application";
import ChatComposerManager from "./chat-composer-manager";

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

  constructor(owner, linkedComponent, primaryModel) {
    setOwner(this, owner);
    this.linkedComponent = linkedComponent;
    this.primaryModel = primaryModel;
    this.composer = new ChatComposerManager(
      getOwner(this),
      this.primaryModel,
      this.linkedComponent
    );
  }

  @action
  setReplyTo(messageOrId) {
    this.composer.setReplyTo(messageOrId);
  }

  @action
  onComposerValueChange({
    value,
    uploads,
    replyToMsg,
    inProgressUploadsCount,
  }) {
    this.composer.onComposerValueChange({
      value,
      uploads,
      replyToMsg,
      inProgressUploadsCount,
    });
  }

  @action
  cancelEditing() {
    this.composer.cancelEditing();
  }

  @action
  editButtonClicked(messageId) {
    this.composer.editButtonClicked(messageId);
  }
}
