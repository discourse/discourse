import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "discourse-rewind-setup",

  initialize(container) {
    this.siteSettings = container.lookup("service:site-settings");
    this.currentUser = container.lookup("service:current-user");
    this.rewind = container.lookup("service:rewind");

    if (!this.currentUser) {
      return;
    }

    if (!this.currentUser.is_rewind_active) {
      return;
    }

    withPluginApi((api) => {
      api.addQuickAccessProfileItem({
        icon: "repeat",
        href: "/my/activity/rewind",
        content: i18n("discourse_rewind.profile_link", {
          rewindYear: this.rewind.fetchRewindYear,
        }),
      });
    });
  },
};
