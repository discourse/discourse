import { withPluginApi } from "discourse/lib/core-api";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    if (!siteSettings.enable_gifs) {
      return;
    }

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        if (!toolbar.context?.composerEvents) {
          return;
        }

        toolbar.addButton({
          id: "gifs",
          group: "extras",
          icon: "gif",
          title: "gifs.composer_title",
          sendAction: () => {
            const modal = api.container.lookup("service:modal");
            modal.show(() => import("discourse/components/modal/gifs"));
          },
        });
      });
    });
  },
};
