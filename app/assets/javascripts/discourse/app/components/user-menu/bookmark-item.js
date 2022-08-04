import UserMenuItem from "discourse/components/user-menu/menu-item";
import { NO_REMINDER_ICON } from "discourse/models/bookmark";
import { postUrl } from "discourse/lib/utilities";

export default class UserMenuBookmarkItem extends UserMenuItem {
  get className() {
    return "bookmark";
  }

  get linkHref() {
    if (["Topic", "Post"].includes(this.bookmark.bookmarkable_type)) {
      let postNumber;
      if (this.bookmark.bookmarkable_type === "Topic") {
        postNumber = this.bookmark.last_read_post_number + 1;
      } else {
        postNumber = this.bookmark.linked_post_number;
      }
      return postUrl(this.bookmark.slug, this.bookmark.topic_id, postNumber);
    } else {
      return this.bookmark.bookmarkable_url;
    }
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
