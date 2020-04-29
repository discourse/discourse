import { withPluginApi } from "discourse/lib/plugin-api";
import PresenceManager from "../discourse/lib/presence-manager";
import ENV from "discourse-common/config/environment";

function initializeDiscoursePresence(api) {
  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("site-settings:main");

  if (currentUser && !currentUser.hide_profile_and_presence) {
    api.modifyClass("model:topic", {
      presenceManager: null
    });

    api.modifyClass("route:topic-from-params", {
      setupController() {
        this._super(...arguments);

        this.modelFor("topic").set(
          "presenceManager",
          PresenceManager.create({
            topic: this.modelFor("topic"),
            currentUser,
            messageBus: api.container.lookup("message-bus:main"),
            siteSettings
          })
        );
      }
    });
  }
}

export default {
  name: "discourse-presence",
  after: "message-bus",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");

    if (siteSettings.presence_enabled && ENV.environment !== "test") {
      withPluginApi("0.8.40", initializeDiscoursePresence);
    }
  }
};
