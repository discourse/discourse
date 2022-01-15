import RawHtml from "discourse/widgets/raw-html";
import { iconHTML } from "discourse-common/lib/icon-library";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { ajax } from "discourse/lib/ajax";
import { createWidget, createWidgetFrom } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { postUrl } from "discourse/lib/utilities";
import I18n from "I18n";

const ICON = "bookmark";

createWidget("no-quick-access-bookmarks", {
  html() {
    return h("div.empty-state", [
      h("span.empty-state-title", I18n.t("user.no_bookmarks_title")),
      h(
        "div.empty-state-body",
        new RawHtml({
          html:
            "<p>" +
            I18n.t("user.no_bookmarks_body", {
              icon: iconHTML(ICON),
            }).htmlSafe() +
            "</p>",
        })
      ),
    ]);
  },
});

createWidgetFrom(QuickAccessPanel, "quick-access-bookmarks", {
  buildKey: () => "quick-access-bookmarks",
  emptyStateWidget: "no-quick-access-bookmarks",

  showAllHref() {
    return `${this.attrs.path}/activity/bookmarks`;
  },

  findNewItems() {
    return this.loadBookmarksWithReminders();
  },

  itemHtml(bookmark) {
    // for topic level bookmarks we want to jump to the last unread post
    // instead of the OP
    let postNumber;
    if (bookmark.for_topic) {
      postNumber = bookmark.last_read_post_number + 1;
    } else {
      postNumber = bookmark.linked_post_number;
    }

    return this.attach("quick-access-item", {
      icon: this.icon(bookmark),
      href: postUrl(bookmark.slug, bookmark.topic_id, postNumber),
      title: bookmark.name,
      content: bookmark.title,
      username: bookmark.post_user_username,
    });
  },

  icon(bookmark) {
    if (bookmark.reminder_at) {
      return "discourse-bookmark-clock";
    }
    return ICON;
  },

  loadBookmarksWithReminders() {
    return ajax(`/u/${this.currentUser.username}/bookmarks.json`).then(
      ({ user_bookmark_list }) => user_bookmark_list.bookmarks
    );
  },
});
