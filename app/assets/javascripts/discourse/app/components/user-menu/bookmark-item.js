import UserMenuItem from "discourse/components/user-menu/menu-item";
import { NO_REMINDER_ICON } from "discourse/models/bookmark";

export default class UserMenuBookmarkItem extends UserMenuItem {
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

  get bookmark() {
    return this.args.item;
  }
}
