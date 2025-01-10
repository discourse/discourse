import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

export default class InteractedChatMessage extends Service {
  @tracked secondaryOptionsOpen = false;
  @tracked emojiPickerOpen = false;
}
