import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";

export default class ChatChannelPane extends Service {
  @service chat;

  @tracked reacting = false;
  @tracked selectingMessages = false;
  @tracked lastSelectedMessage = null;
  @tracked sending = false;

  get channel() {
    return this.chat.activeChannel;
  }

  get selectedMessageIds() {
    return this.channel.messagesManager.selectedMessages.mapBy("id");
  }

  @action
  cancelSelecting() {
    this.selectingMessages = false;
    this.channel.messagesManager.clearSelectedMessages();
  }

  @action
  onSelectMessage(message) {
    this.lastSelectedMessage = message;
    this.selectingMessages = true;
  }
}
