import { service } from "@ember/service";
import ClassBasedInitializer from "discourse/lib/class-based-initializer";
import { bind } from "discourse-common/utils/decorators";

// Subscribe to "read-only" status change events via the Message Bus
export default class extends ClassBasedInitializer {
  static after = "message-bus";

  @service messageBus;
  @service site;

  initialize() {
    this.messageBus.subscribe("/site/read-only", this.onMessage);
  }

  willDestroy() {
    this.messageBus.unsubscribe("/site/read-only", this.onMessage);
  }

  @bind
  onMessage(enabled) {
    this.site.set("isReadOnly", enabled);
  }
}
