import I18n from "I18n";
import bootbox from "bootbox";
import { later } from "@ember/runloop";

//  Subscribe to "asset-version" change events via the Message Bus
export default {
  name: "asset-version",
  after: "message-bus",

  initialize(container) {
    let timeout;
    const messageBus = container.lookup("message-bus:main");
    if (!messageBus) {
      return;
    }

    let session = container.lookup("session:main");
    messageBus.subscribe("/refresh_client", () => {
      session.requiresRefresh = true;
    });

    messageBus.subscribe("/global/asset-version", function (version) {
      if (session.assetVersion !== version) {
        session.requiresRefresh = true;
      }

      if (!timeout && session.requiresRefresh) {
        // Since we can do this transparently for people browsing the forum
        // hold back the message 24 hours.
        timeout = later(() => {
          bootbox.confirm(I18n.t("assets_changed_confirm"), function (result) {
            if (result) {
              document.location.reload();
            }
          });
        }, 1000 * 60 * 24 * 60);
      }
    });
  },
};
