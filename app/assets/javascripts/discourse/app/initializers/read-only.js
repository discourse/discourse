import { bind } from "discourse-common/utils/decorators";

// Subscribe to "read-only" status change events via the Message Bus
export default {
  name: "read-only",
  after: "message-bus",

  initialize(container) {
    this.messageBus = container.lookup("service:message-bus");
    this.site = container.lookup("service:site");

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
