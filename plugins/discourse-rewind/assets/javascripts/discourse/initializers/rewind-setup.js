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
      api.addUserNavPreferencesLink({
        name: "preferences-rewind",
        route: "preferences.rewind",
        label: "discourse_rewind.title",
        icon: "repeat",
        // Same conditions as `RewindPreferencesNav` in the horizontal nav: the
        // site setting gates the tab so it does not vanish when a user turns
        // rewind off for themselves, and `active` reflects the viewer's state.
        displayed: ({ siteSettings, owner }) =>
          siteSettings.discourse_rewind_enabled &&
          !!owner.lookup("service:rewind")?.active,
      });

      if (this.rewind.enabled) {
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
