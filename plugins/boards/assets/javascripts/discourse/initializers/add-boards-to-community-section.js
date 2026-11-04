import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "add-boards-to-community-section",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.boards_enabled) {
      return;
    }

    withPluginApi((api) => {
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
