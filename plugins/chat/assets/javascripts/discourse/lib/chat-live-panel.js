import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { TrackedArray } from "@ember-compat/tracked-built-ins";

export default class ChatLivePanel {
  @tracked messages = new TrackedArray();

  @tracked selectingMessages;
  @tracked lastSelectedMessage;

  onSelectMessage(message) {
    this.lastSelectedMessage = message;
    this.selectingMessages = true;
  }

  @action
  cancelSelecting() {
    this.selectingMessages = false;
    this.lastSelectedMessage = null;
    this.messages.setEach("selected", false);
  }

  get selectedMessageIds() {
    return this.messages.filterBy("selected").mapBy("id");
  }
}
