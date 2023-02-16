import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";

export default class ChatLivePaneReactor {
  @tracked messages = new TrackedArray();

  @tracked selectingMessages;
  @tracked lastSelectedMessage;

  onSelectMessage(message) {
    this.lastSelectedMessage = message;
    this.selectingMessages = true;
  }

  get selectedMessageIds() {
    return this.messages.filterBy("selected").mapBy("id");
  }
}
