import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

export default {
  name: "add-upcoming-events-to-sidebar",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (
      siteSettings.discourse_post_event_enabled &&
      siteSettings.sidebar_show_upcoming_events
    ) {
      withPluginApi("0.8.7", (api) => {
        api.addCommunitySectionLink((baseSectionLink) => {
          return class UpcomingEventsSectionLink extends baseSectionLink {
            name = "upcoming-events";
            route = "discourse-post-event-upcoming-events";
            text = i18n("discourse_post_event.upcoming_events.title");
            title = i18n("discourse_post_event.upcoming_events.title");
            defaultPrefixValue = "calendar-day";
          };
        });
      });
    }
  },
};
