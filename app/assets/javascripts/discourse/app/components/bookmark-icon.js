import { isEmpty } from "@ember/utils";
import I18n from "I18n";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { computed } from "@ember/object";
import Component from "@ember/component";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";

export default class BookmarkIcon extends Component {
  tagName = "";
  bookmark = null;

  @computed("bookmark.reminder_at")
  get icon() {
    if (!this.bookmark) {
      return NO_REMINDER_ICON;
    }

    if (!isEmpty(this.bookmark.reminder_at)) {
      return WITH_REMINDER_ICON;
    }

    return NO_REMINDER_ICON;
  }

  @computed("bookmark")
  get cssClasses() {
    return this.bookmark
      ? "bookmark-icon bookmark-icon__bookmarked"
      : "bookmark-icon";
  }

  @computed("bookmark.name", "bookmark.reminder_at")
  get title() {
    if (!this.bookmark) {
      return I18n.t("bookmarks.create");
    }

    if (!isEmpty(this.bookmark.reminder_at)) {
      const formattedTime = formattedReminderTime(
        this.bookmark.reminder_at,
        this.currentUser.user_option.timezone
      );
      return I18n.t("bookmarks.created_with_reminder_generic", {
        date: formattedTime,
        name: this.bookmark.name,
      });
    }

    return I18n.t("bookmarks.created_generic", {
      name: this.bookmark.name,
    });
  }
}
