import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";

function initialize(api) {
  const messageBus = api.container.lookup("message-bus:main");
  const currentUser = api.getCurrentUser();
  const appEvents = api.container.lookup("service:app-events");

  api.modifyClass("component:site-header", {
    didInsertElement() {
      this._super(...arguments);
      this.dispatch("header:search-context-trigger", "header");
    }
  });

  api.modifyClass("model:post", {
    toggleBookmark() {
      // if we are talking to discobot then any bookmarks should just
      // be created without reminder options, to streamline the new user
      // narrative.
      const discobotUserId = -2;
      if (this.user_id === discobotUserId && !this.bookmarked) {
        return ajax("/bookmarks", {
          type: "POST",
          data: { post_id: this.id }
        }).then(response => {
          this.setProperties({
            "topic.bookmarked": true,
            bookmarked: true,
            bookmark_id: response.id
          });
          this.appEvents.trigger("post-stream:refresh", { id: this.id });
        });
      }
      return this._super();
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
