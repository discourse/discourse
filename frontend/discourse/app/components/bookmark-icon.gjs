import Component from "@glimmer/component";
import {
  NO_REMINDER_ICON,
  NOT_BOOKMARKED,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class BookmarkIcon extends Component {
  get icon() {
    if (this.args.bookmark?.get("reminder_at")) {
      return WITH_REMINDER_ICON;
    } else if (this.args.bookmark) {
      return NO_REMINDER_ICON;
    }

    return NOT_BOOKMARKED;
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
    {{dIcon this.icon translatedTitle=this.title class=this.cssClasses}}
  </template>
}
