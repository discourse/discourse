import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "assign-extend-user-messages",

  initialize(container) {
    withPluginApi("1.5.0", (api) => {
      const currentUser = container.lookup("service:current-user");

      if (currentUser?.can_assign && api.addUserMessagesNavigationDropdownRow) {
        api.addUserMessagesNavigationDropdownRow(
          "userPrivateMessages.assigned",
          i18n("discourse_assign.assigned"),
          "user-plus"
        );
      }
    });
  },
};
