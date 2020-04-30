import { withPluginApi } from "discourse/lib/plugin-api";
import PresenceManager from "../lib/presence-manager";
import ENV from "discourse-common/config/environment";

function initializeDiscoursePresence(api, { app }) {
  const currentUser = api.getCurrentUser();

  if (currentUser) {
    app.register(
      "presence-manager:main",
      PresenceManager.create({
        currentUser,
        messageBus: api.container.lookup("message-bus:main"),
        siteSettings: api.container.lookup("site-settings:main")
      }),
      { instantiate: false }
    );
  }
}

export default {
  name: "discourse-presence",
  after: "message-bus",

  initialize(container, app) {
    const siteSettings = container.lookup("site-settings:main");

    if (siteSettings.presence_enabled && ENV.environment !== "test") {
      withPluginApi("0.8.40", initializeDiscoursePresence, { app });
    }
  }
};
