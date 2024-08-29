import EmberObject from "@ember/object";
import { service } from "@ember/service";
import ClassBasedInitializer from "discourse/lib/class-based-initializer";
import PreloadStore from "discourse/lib/preload-store";
import { bind } from "discourse-common/utils/decorators";

export default class extends ClassBasedInitializer {
  static after = "message-bus";

  @service site;
  @service messageBus;

  initialize() {
    const banner = EmberObject.create(PreloadStore.get("banner") || {});
    this.site.set("banner", banner);

    this.messageBus.subscribe("/site/banner", this.onMessage);
  }

  willDestroy() {
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
