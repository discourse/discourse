import { applyLocalDates } from "discourse/lib/local-dates";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "chat-plugin-decorators",

  initializeWithPluginApi(api, siteSettings) {
    api.decorateChatMessage(
      (element) => {
        applyLocalDates(
          element.querySelectorAll(".discourse-local-date"),
          siteSettings
        );
      },
      {
        id: "local-dates",
      }
    );

    if (siteSettings.spoiler_enabled) {
      const applySpoiler = requirejs(
        "discourse/plugins/spoiler-alert/lib/apply-spoiler"
      ).default;
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
      withPluginApi((api) => {
        this.initializeWithPluginApi(api, siteSettings);
      });
    }
  },
};
