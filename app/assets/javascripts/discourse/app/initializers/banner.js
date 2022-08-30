import EmberObject from "@ember/object";
import PreloadStore from "discourse/lib/preload-store";

export default {
  name: "banner",
  after: "message-bus",

  initialize(container) {
    const banner = EmberObject.create(PreloadStore.get("banner") || {}),
      site = container.lookup("service:site");

    site.set("banner", banner);

    const messageBus = container.lookup("service:message-bus");
    if (!messageBus) {
      return;
    }

    messageBus.subscribe("/site/banner", function (ban) {
      site.set("banner", EmberObject.create(ban || {}));
    });
  },
};
