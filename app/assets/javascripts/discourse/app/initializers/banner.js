import EmberObject from "@ember/object";
import PreloadStore from "discourse/lib/preload-store";

export default {
  name: "banner",
  after: "message-bus",

  initialize(container) {
    const site = container.lookup("service:site");
    const banner = EmberObject.create(PreloadStore.get("banner") || {});
    const messageBus = container.lookup("service:message-bus");

    site.set("banner", banner);

    messageBus.subscribe("/site/banner", (data) => {
      site.set("banner", EmberObject.create(data || {}));
    });
  },
};
