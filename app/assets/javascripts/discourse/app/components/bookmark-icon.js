import Component from "@ember/component";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

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

  @computed("bookmark.title")
  get title() {
    if (!this.bookmark) {
      return i18n("bookmarks.create");
    }

    return this.bookmark.reminderTitle;
  }
}
