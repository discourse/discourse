import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class ChatChannelScrollPositions extends Service {
  @tracked positions = new Map();
}
