import { withPluginApi } from "discourse/lib/plugin-api";
import RewindHeaderIcon from "../components/rewind-header-icon";

export default {
  name: "discourse-rewind-setup",
  initialize(container) {
    this.siteSettings = container.lookup("service:site-settings");
    this.currentUser = container.lookup("service:current-user");

    if (!this.currentUser) {
      return;
    }

    if (!this.currentUser.is_rewind_active) {
      return;
    }

    withPluginApi((api) => {
      api.headerIcons.add("discourse-rewind", RewindHeaderIcon, {
        before: "hamburger",
      });
    });
  },
};
