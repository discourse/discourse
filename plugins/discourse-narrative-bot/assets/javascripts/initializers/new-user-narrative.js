import { withPluginApi } from "discourse/lib/plugin-api";
import { bind } from "discourse-common/utils/decorators";

export default {
  name: "new-user-narrative",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.discourse_narrative_bot_enabled) {
      return;
    }

    this.messageBus = container.lookup("service:message-bus");
    this.appEvents = container.lookup("service:app-events");

    withPluginApi("0.8.7", (api) => {
      this.currentUser = api.getCurrentUser();

      if (!this.currentUser) {
        return;
      }

      api.dispatchWidgetAppEvent(
        "site-header",
        "header",
        "header:search-context-trigger"
      );

      api.attachWidgetAction(
        "header",
        "headerSearchContextTrigger",
        function () {
          if (this.site.mobileView) {
            this.state.skipSearchContext = false;
          } else {
            this.state.contextEnabled = true;
            this.state.searchContextType = "topic";
          }
        }
      );

      this.messageBus.subscribe(
        `/new_user_narrative/tutorial_search/${this.currentUser.id}`,
        this.onMessage
      );
    });
  },

  teardown() {
    if (this.currentUser) {
      this.messageBus?.unsubscribe(
        `/new_user_narrative/tutorial_search/${this.currentUser.id}`,
        this.onMessage
      );
    }
  },

  @bind
  onMessage() {
    this.appEvents.trigger("header:search-context-trigger");
  },
};
