import { applyLocalDates } from "discourse/lib/local-dates";
import { withPluginApi } from "discourse/lib/plugin-api";
import { optionalRequire } from "discourse/lib/utilities";

export default {
  name: "chat-plugin-decorators",

  initializeWithPluginApi(api, siteSettings, currentUser) {
    api.decorateChatMessage(
      (element) => {
        applyLocalDates(
          element.querySelectorAll(".discourse-local-date"),
          siteSettings,
          currentUser?.user_option?.timezone
        );
      },
      {
        id: "local-dates",
      }
    );

    if (siteSettings.spoiler_enabled) {
      const applySpoiler = optionalRequire(
        "discourse/plugins/spoiler-alert/lib/apply-spoiler"
      );

      api.decorateChatMessage(
        (element) => {
          element.querySelectorAll(".spoiler").forEach((spoiler) => {
            spoiler.classList.remove("spoiler");
            spoiler.classList.add("spoiled");
            applySpoiler(spoiler);
          });
        },
        {
          id: "spoiler",
        }
      );
    }
  },

  initialize(container) {
    if (container.lookup("service:chat").userCanChat) {
      const siteSettings = container.lookup("service:site-settings");
      const currentUser = container.lookup("service:current-user");
      withPluginApi((api) => {
        this.initializeWithPluginApi(api, siteSettings, currentUser);
      });
    }
  },
};
