import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedMap } from "tracked-built-ins";

export default class ChatChannelScrollPositions extends Service {
  @tracked positions = new TrackedMap();

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
