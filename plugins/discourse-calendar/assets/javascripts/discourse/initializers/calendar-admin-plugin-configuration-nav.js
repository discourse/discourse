import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-calendar";

export default {
  name: "calendar-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.setAdminPluginIcon(PLUGIN_ID, "calendar-days");

      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
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
