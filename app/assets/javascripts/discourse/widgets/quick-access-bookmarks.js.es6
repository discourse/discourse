import { h } from "virtual-dom";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import UserAction from "discourse/models/user-action";
import { ajax } from "discourse/lib/ajax";
import { createWidgetFrom } from "discourse/widgets/widget";
import { postUrl } from "discourse/lib/utilities";

const ICON = "bookmark";

let staleItems = [];

// The empty state help text for bookmarks page is localized on the server.
let emptyStatePlaceholderItemText = "";

createWidgetFrom(QuickAccessPanel, "quick-access-bookmarks", {
  buildKey: () => "quick-access-bookmarks",

  hasMore() {
    // Always show the button to the bookmarks page.
    return true;
  },

  showAllHref() {
    return `${this.attrs.path}/activity/bookmarks`;
  },

  emptyStatePlaceholderItem() {
    return h("li.read", emptyStatePlaceholderItemText);
  },

  findStaleItems() {
    return staleItems || [];
  },

  findNewItems() {
    return ajax("/user_actions.json", {
      cache: "false",
      data: {
        username: this.currentUser.username,
        filter: UserAction.TYPES.bookmarks,
        limit: this.estimateItemLimit(),
        no_results_help_key: "user_activity.no_bookmarks"
      }
    }).then(({ user_actions, no_results_help }) => {
      emptyStatePlaceholderItemText = no_results_help;
      return (staleItems = user_actions.slice(0, this.estimateItemLimit()));
    });
  },

  itemHtml(bookmark) {
    return this.attach("quick-access-item", {
      icon: ICON,
      href: postUrl(bookmark.slug, bookmark.topic_id, bookmark.post_number),
      content: bookmark.title,
      username: bookmark.username
    });
  }
});
