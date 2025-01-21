import EmberObject from "@ember/object";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import PreloadStore from "discourse/lib/preload-store";

class BannerInit {
  @service site;
  @service messageBus;

  constructor(owner) {
    setOwner(this, owner);

    const banner = EmberObject.create(PreloadStore.get("banner") || {});
    this.site.set("banner", banner);

    this.messageBus.subscribe("/site/banner", this.onMessage);
  }

  teardown() {
    this.messageBus.unsubscribe("/site/banner", this.onMessage);
  }

  @bind
  onMessage(data) {
    if (data) {
      this.site.set("banner", EmberObject.create(data));
    } else {
      this.site.set("banner", null);
    }
  }
}

export default {
  after: "message-bus",

  initialize(owner) {
    this.instance = new BannerInit(owner);
  },

  teardown() {
    this.instance.teardown();
    this.instance = null;
  },
};
