import { routeWithin } from "discourse/lib/mobile-tab-bar";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { UPCOMING_EVENTS_TAB_KEY } from "../lib/upcoming-events-tab.js";

export default {
  name: "add-upcoming-events-to-sidebar",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (
      siteSettings.discourse_post_event_enabled &&
      siteSettings.sidebar_show_upcoming_events
    ) {
      withPluginApi((api) => {
        api.addCommunitySectionLink((baseSectionLink) => {
          return class UpcomingEventsSectionLink extends baseSectionLink {
            name = "upcoming-events";
            route = "discourse-post-event-upcoming-events";
            text = i18n("discourse_post_event.upcoming_events.title");
            title = i18n("discourse_post_event.upcoming_events.title");
            defaultPrefixValue = "calendar-day";
          };
        });

        api.addSidebarPanel(
          (BaseCustomSidebarPanel) =>
            class UpcomingEventsPanel extends BaseCustomSidebarPanel {
              hidden = true;
              key = UPCOMING_EVENTS_TAB_KEY;

              get mobileTab() {
                return {
                  label: i18n("discourse_events.title"),
                  icon: "calendar-day",
                  url: "/upcoming-events",
                  ownsRoute: (route) =>
                    routeWithin(route, "discourse-post-event-upcoming-events"),
                };
              }
            }
        );
      });
    }
  },
};
