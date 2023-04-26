import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";

export default class ChatChannelPane extends Service {
  @service appEvents;
  @service chat;
  @service chatChannelComposer;
  @service chatApi;
  @service chatComposerPresenceManager;

  @tracked reacting = false;
  @tracked selectingMessages = false;
  @tracked lastSelectedMessage = null;
  @tracked sending = false;

  get selectedMessageIds() {
    return this.chat.activeChannel?.selectedMessages?.mapBy("id") || [];
  }

  get composerService() {
    return this.chatChannelComposer;
  }

  get channel() {
    return this.chat.activeChannel;
  }

  @action
  cancelSelecting(selectedMessages) {
    this.selectingMessages = false;

    selectedMessages.forEach((message) => {
      message.selected = false;
    });
  }

  onSelectMessage(message) {
    this.lastSelectedMessage = message;
    this.selectingMessages = true;
  }

  get lastCurrentUserMessage() {
    const lastCurrentUserMessage = this.chat.activeChannel.messages.findLast(
      (message) => message.user.id === this.currentUser.id
    );

    if (!lastCurrentUserMessage) {
      return;
    }

    if (lastCurrentUserMessage.staged || lastCurrentUserMessage.error) {
      return;
    }

    return lastCurrentUserMessage;
  }
}
