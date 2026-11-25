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

      const label = i18n("boards.manage.title");
      api.addCommunitySectionLink({
        name: "boards",
        route: "boards",
        icon: "boards",
        text: label,
        title: label,
      });

      api.addSidebarPanel(
        (BaseCustomSidebarPanel) =>
          class BoardsSidebarPanel extends BaseCustomSidebarPanel {
            hidden = true;
            key = "boards";

            get mobileTab() {
              return {
                label,
                icon: "boards",
                url: "/boards",
                ownsRoute: ({ name }) =>
                  name === "boards" || name.startsWith("boardsBoard"),
                isNestedRoute: ({ name }) => name !== "boards",
              };
            }
          }
      );
    });
  },
};
