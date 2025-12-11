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

    if (!this.rewind.active) {
      return;
    }

    withPluginApi((api) => {
      if (!this.rewind.disabled) {
        api.addQuickAccessProfileItem({
          icon: "repeat",
          href: "/my/activity/rewind",
          content: i18n("discourse_rewind.profile_link", {
            rewindYear: this.rewind.fetchRewindYear,
          }),
        });
      }
    });
  },
};
