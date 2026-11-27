import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-events";

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
          label: "discourse_events.holidays.header_title",
          route: "adminPlugins.show.discourse-events-holidays",
          description:
            "discourse_events.holidays.disabled_holidays_description",
        },
        {
          label: "event_registration.library.title",
          route: "adminPlugins.show.discourse-events-registration-forms",
          description: "event_registration.library.description",
        },
        {
          label: "event_registration.submissions.title",
          route: "adminPlugins.show.discourse-events-submissions",
          description: "event_registration.submissions.description",
        },
      ]);
    });
  },
};
