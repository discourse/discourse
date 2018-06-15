import { withPluginApi } from "discourse/lib/plugin-api";

function initialize(api) {
  const messageBus = api.container.lookup("message-bus:main");
  const currentUser = api.getCurrentUser();
  const appEvents = api.container.lookup("app-events:main");

  api.modifyClass("component:site-header", {
    didInsertElement() {
      this._super();
      this.dispatch("header:search-context-trigger", "header");
    }
  });

  api.attachWidgetAction("header", "headerSearchContextTrigger", function() {
    if (this.site.mobileView) {
      this.state.skipSearchContext = false;
    } else {
      this.state.contextEnabled = true;
      this.state.searchContextType = "topic";
    }
  });

  if (messageBus && currentUser) {
    messageBus.subscribe(`/new_user_narrative/tutorial_search`, () => {
      appEvents.trigger("header:search-context-trigger");
    });
  }
}

export default {
  name: "new-user-narratve",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_narrative_bot_enabled)
      withPluginApi("0.8.7", initialize);
  }
};
