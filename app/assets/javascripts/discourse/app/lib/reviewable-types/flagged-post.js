import ReviewableTypeBase from "discourse/lib/reviewable-types/base";
import { htmlSafe } from "@ember/template";
import I18n from "I18n";
import { emojiUnescape } from "discourse/lib/text";

export default class extends ReviewableTypeBase {
  get description() {
    const title = this.reviewable.topic_fancy_title;
    const postNumber = this.reviewable.post_number;
    if (title && postNumber) {
      return htmlSafe(
        I18n.t("user_menu.reviewable.post_number_with_topic_title", {
          post_number: postNumber,
          title: emojiUnescape(title),
        })
      );
    } else {
      return I18n.t("user_menu.reviewable.deleted_post");
    }
  }
}
