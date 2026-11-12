import { tracked } from "@glimmer/tracking";
import { trackedMap } from "@ember/reactive/collections";
import Service from "@ember/service";

export default class ChatChannelScrollPositions extends Service {
  @tracked positions = trackedMap();

  get(id) {
    return this.positions.get(id);
  }

  set(id, position) {
    this.positions.set(id, position);
  }

  delete(id) {
    if (this.positions.has(id)) {
      this.positions.delete(id);
    }
  }
}
