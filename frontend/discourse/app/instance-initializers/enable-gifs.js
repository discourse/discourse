import GifsModal from "discourse/components/modal/gifs";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    const siteSettings = owner.lookup("service:site-settings");

    if (!siteSettings.enable_gifs) {
      return;
    }

    withPluginApi((api) => {
      api.onToolbarCreate((toolbar) => {
        // GIFs move into the unified composer-picker tab when its upcoming
        // change is on, so the standalone modal button only shows when off.
        if (siteSettings.enable_unified_composer_picker) {
          return;
        }

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
            modal.show(GifsModal);
          },
        });
      });
    });
  },
};
