import UserMenuBaseItem from "discourse/lib/user-menu/base-item";
import { postUrl } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";
import { emojiUnescape } from "discourse/lib/text";
import I18n from "I18n";

export default class UserMenuMessageItem extends UserMenuBaseItem {
  constructor({ message }) {
    super(...arguments);
    this.message = message;
  }

  get className() {
    return "message";
  }

  get linkHref() {
    const nextUnreadPostNumber = Math.min(
      (this.message.last_read_post_number || 0) + 1,
      this.message.highest_post_number
    );
    return postUrl(this.message.slug, this.message.id, nextUnreadPostNumber);
  }

  get linkTitle() {
    return I18n.t("user.private_message");
  }

  get icon() {
    return "notification.private_message";
  }

  get label() {
    return this.message.last_poster_username;
  }

  get description() {
    return htmlSafe(emojiUnescape(this.message.fancy_title));
  }

  get topicId() {
    return this.message.id;
  }
}
