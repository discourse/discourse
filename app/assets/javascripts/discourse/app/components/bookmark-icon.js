import { isEmpty } from "@ember/utils";
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
    if (!isEmpty(this.bookmark.reminder_at)) {
      return WITH_REMINDER_ICON;
    }

    return NO_REMINDER_ICON;
  }
}
