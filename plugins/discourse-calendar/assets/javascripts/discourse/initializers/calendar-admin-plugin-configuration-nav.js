import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-calendar-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav("discourse-calendar", [
        {
          label: "discourse_calendar.holidays.header_title",
          route: "adminPlugins.show.discourse-calendar-holidays",
          description:
            "discourse_calendar.holidays.disabled_holidays_description",
        },
      ]);
    });
  },
};
