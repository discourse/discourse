import RawHtml from "discourse/widgets/raw-html";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import { iconHTML } from "discourse-common/lib/icon-library";
import QuickAccessPanel from "discourse/widgets/quick-access-panel";
import { ajax } from "discourse/lib/ajax";
import { createWidget, createWidgetFrom } from "discourse/widgets/widget";
import { h } from "@discourse/virtual-dom";
import { postUrl } from "discourse/lib/utilities";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

createWidget("no-quick-access-bookmarks", {
  html() {
    return h("div.empty-state", [
      h("span.empty-state-title", I18n.t("user.no_bookmarks_title")),
      h(
        "div.empty-state-body",
        new RawHtml({
          html:
            "<p>" +
            htmlSafe(
              I18n.t("user.no_bookmarks_body", {
                icon: iconHTML(NO_REMINDER_ICON),
              })
            ) +
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
    if (bookmark.bookmarkable_type === "Topic") {
      postNumber = bookmark.last_read_post_number + 1;
    } else {
      postNumber = bookmark.linked_post_number;
    }

    let href;
    if (
      bookmark.bookmarkable_type === "Topic" ||
      bookmark.bookmarkable_type === "Post"
    ) {
      href = postUrl(bookmark.slug, bookmark.topic_id, postNumber);
    } else {
      href = bookmark.bookmarkable_url;
    }

    return this.attach("quick-access-item", {
      icon: this.icon(bookmark),
      href,
      title: bookmark.name,
      content: bookmark.title,
      username: bookmark.user?.username,
    });
  },

  icon(bookmark) {
    if (bookmark.reminder_at) {
      return WITH_REMINDER_ICON;
    }
    return NO_REMINDER_ICON;
  },

  loadBookmarksWithReminders() {
    return ajax(`/u/${this.currentUser.username}/bookmarks.json`).then(
      ({ user_bookmark_list }) => user_bookmark_list.bookmarks
    );
  },
});
