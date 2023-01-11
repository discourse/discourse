import UserMenuBaseItem from "discourse/lib/user-menu/base-item";
import { NO_REMINDER_ICON } from "discourse/models/bookmark";

export default class UserMenuBookmarkItem extends UserMenuBaseItem {
  constructor({ bookmark }) {
    super(...arguments);
    this.bookmark = bookmark;
  }

  get className() {
    return "bookmark";
  }

  get linkHref() {
    return this.bookmark.bookmarkable_url;
  }

  get linkTitle() {
    return this.bookmark.name;
  }

  get icon() {
    return NO_REMINDER_ICON;
  }

  get label() {
    return this.bookmark.user?.username;
  }

  get description() {
    return this.bookmark.title;
  }

  get topicId() {
    return this.bookmark.topic_id;
  }
}
