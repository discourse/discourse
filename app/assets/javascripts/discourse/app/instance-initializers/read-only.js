import { bind } from "discourse-common/utils/decorators";

// Subscribe to "read-only" status change events via the Message Bus
export default {
  after: "message-bus",

  initialize(owner) {
    this.messageBus = owner.lookup("service:message-bus");
    this.site = owner.lookup("service:site");

    this.messageBus.subscribe("/site/read-only", this.onMessage);
  },

  teardown() {
    this.messageBus.unsubscribe("/site/read-only", this.onMessage);
  },

  @bind
  onMessage(enabled) {
    this.site.set("isReadOnly", enabled);
  },
};
