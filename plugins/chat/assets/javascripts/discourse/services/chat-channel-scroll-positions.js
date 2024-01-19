import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { TrackedMap } from "@ember-compat/tracked-built-ins";

export default class ChatChannelScrollPositions extends Service {
  @tracked positions = new TrackedMap();

  add(channelId, position) {
    this.positions.set(channelId, position);
  }

  remove(channelId) {
    if (this.positions.has(channelId)) {
      this.positions.delete(channelId);
    }
  }
}
