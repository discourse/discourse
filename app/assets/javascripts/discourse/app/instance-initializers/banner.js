import EmberObject from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import PreloadStore from "discourse/lib/preload-store";

export default {
  after: "message-bus",

  initialize(owner) {
    this.site = owner.lookup("service:site");
    this.messageBus = owner.lookup("service:message-bus");

    const banner = EmberObject.create(PreloadStore.get("banner") || {});
    this.site.set("banner", banner);

    this.messageBus.subscribe("/site/banner", this.onMessage);
  },

  teardown() {
    this.messageBus.unsubscribe("/site/banner", this.onMessage);
  },

  @bind
  onMessage(data) {
    if (data) {
      this.site.set("banner", EmberObject.create(data));
    } else {
      this.site.set("banner", null);
    }
  },
};
