import { lookup } from "discourse/lib/service";
import { withPluginApi } from "discourse/lib/core-api";
import SiteSettingsService from "discourse/services/site-settings";
import ModalService from "discourse/services/modal";

export default {
  initialize(owner) {
    const siteSettings = lookup(owner, SiteSettingsService);

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
            const modal = lookup(api.container, ModalService);
            modal.show(() => import("discourse/components/modal/gifs"));
          },
        });
      });
    });
  },
};
