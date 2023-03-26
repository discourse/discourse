import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";

export default class ChatChannelPane extends Service {
  @service chat;

  @tracked reacting = false;
  @tracked selectingMessages = false;
  @tracked hoveredMessageId = false;
  @tracked lastSelectedMessage = null;

  get selectedMessageIds() {
    return this.chat.activeChannel.selectedMessages.map((m) => m.id);
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
}
