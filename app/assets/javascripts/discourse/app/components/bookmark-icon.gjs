import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

export default class BookmarkIcon extends Component {
  get icon() {
    if (this.args.bookmark?.get("reminder_at")) {
      return WITH_REMINDER_ICON;
    }

    return NO_REMINDER_ICON;
  }

  get cssClasses() {
    return this.args.bookmark
      ? "bookmark-icon bookmark-icon__bookmarked"
      : "bookmark-icon";
  }

  get title() {
    if (!this.args.bookmark) {
      return i18n("bookmarks.create");
    }

    return this.args.bookmark.get("reminderTitle");
  }

  <template>
    {{icon this.icon translatedTitle=this.title class=this.cssClasses}}
  </template>
}
