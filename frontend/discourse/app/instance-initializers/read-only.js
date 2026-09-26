import { setOwner } from "@ember/owner";
import { service } from "discourse/lib/service";
import { bind } from "discourse/lib/decorators";
import MessageBusService from "discourse/services/message-bus";
import SiteService from "discourse/services/site";

// Subscribe to "read-only" status change events via the Message Bus
class ReadOnlyInit {
  @service(() => MessageBusService) messageBus;
  @service(() => SiteService) site;

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
