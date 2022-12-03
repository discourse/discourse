import { withPluginApi } from "discourse/lib/plugin-api";

function initialize(api) {
  const currentUser = api.getCurrentUser();

  if (!currentUser) {
    return;
  }

  api.dispatchWidgetAppEvent(
    "site-header",
    "header",
    "header:search-context-trigger"
  );

  api.attachWidgetAction("header", "headerSearchContextTrigger", function () {
    if (this.site.mobileView) {
      this.state.skipSearchContext = false;
    } else {
      this.state.contextEnabled = true;
      this.state.searchContextType = "topic";
    }
  });

  const messageBus = api.container.lookup("service:message-bus");
  const appEvents = api.container.lookup("service:app-events");

  messageBus.subscribe(`/new_user_narrative/tutorial_search`, () => {
    appEvents.trigger("header:search-context-trigger");
  });
}

export default {
  name: "new-user-narrative",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_narrative_bot_enabled) {
      withPluginApi("0.8.7", initialize);
    }
  },
};
