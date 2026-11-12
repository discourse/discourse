import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import { i18n } from "discourse-i18n";

export default {
  name: "add-boards-to-community-section",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.boards_enabled) {
      return;
    }

    const currentUser = container.lookup("service:current-user");

    withPluginApi((api) => {
      if (currentUser) {
        if (!currentUser.can_see_any_boards) {
          return;
        }
      } else if (!PreloadStore.get("boards:visibility")?.can_see_any_boards) {
        return;
      }

      api.addCommunitySectionLink({
        name: "boards",
        route: "boards",
        icon: "boards",
        text: i18n("boards.manage.title"),
        title: i18n("boards.manage.title"),
      });
    });
  },
};
