import UserMenuDefaultReviewableItem from "discourse/components/user-menu/default-reviewable-item";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";
import { emojiUnescape } from "discourse/lib/text";

export default class UserMenuReviewableQueuedPostItem extends UserMenuDefaultReviewableItem {
  get actor() {
    return I18n.t("user_menu.reviewable.queue");
  }

  get description() {
    let title = this.reviewable.topic_fancy_title;
    if (!title) {
      title = escapeExpression(this.reviewable.payload_title);
    }
    title = emojiUnescape(title);
    if (this.reviewable.is_new_topic) {
      return htmlSafe(title);
    } else {
      return htmlSafe(
        I18n.t("user_menu.reviewable.new_post_in_topic", {
          title,
        })
      );
    }
  }

  get icon() {
    return "layer-group";
  }
}
