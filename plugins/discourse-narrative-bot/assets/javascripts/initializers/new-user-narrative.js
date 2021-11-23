import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "new-user-narrative";

function initialize(api) {
  const messageBus = api.container.lookup("message-bus:main");
  const currentUser = api.getCurrentUser();
  const appEvents = api.container.lookup("service:app-events");

  api.modifyClass("component:site-header", {
    pluginId: PLUGIN_ID,
    didInsertElement() {
      this._super(...arguments);
      this.dispatch("header:search-context-trigger", "header");
    },
  });

  api.modifyClass("controller:topic", {
    pluginId: PLUGIN_ID,

    _modifyBookmark(bookmark, post) {
      // if we are talking to discobot then any bookmarks should just
      // be created without reminder options, to streamline the new user
      // narrative.
      const discobotUserId = -2;
      if (post && post.user_id === discobotUserId && !post.bookmarked) {
        return ajax("/bookmarks", {
          type: "POST",
          data: { post_id: post.id },
        }).then((response) => {
          post.setProperties({
            "topic.bookmarked": true,
            bookmarked: true,
            bookmark_id: response.id,
          });
          post.appEvents.trigger("post-stream:refresh", { id: this.id });
        });
      }
      return this._super(bookmark, post);
    },
  });

  api.attachWidgetAction("header", "headerSearchContextTrigger", function () {
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
    if (siteSettings.discourse_narrative_bot_enabled) {
      withPluginApi("0.8.7", initialize);
    }
  },
};
