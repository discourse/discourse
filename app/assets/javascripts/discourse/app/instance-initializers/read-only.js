import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";

// Subscribe to "read-only" status change events via the Message Bus
class ReadOnlyInit {
  @service messageBus;
  @service site;

  constructor(owner) {
    setOwner(this, owner);

    this.messageBus.subscribe("/site/read-only", this.onMessage);
  }

  teardown() {
    this.messageBus.unsubscribe("/site/read-only", this.onMessage);
  }

  @bind
  onMessage(enabled) {
    this.site.set("isReadOnly", enabled);
  }
}

export default {
  after: "message-bus",

  initialize(owner) {
    this.instance = new ReadOnlyInit(owner);
  },

  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
