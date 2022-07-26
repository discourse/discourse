import UserMenuDefaultReviewableItem from "discourse/components/user-menu/default-reviewable-item";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";

export default class UserMenuReviewableQueuedPostItem extends UserMenuDefaultReviewableItem {
  get actor() {
    return I18n.t("user_menu.reviewable.queue");
  }

  get description() {
    const fancyTitle = this.reviewable.topic_fancy_title;
    const payloadTitle = this.reviewable.payload_title;
    if (this.reviewable.is_new_topic) {
      if (fancyTitle) {
        return htmlSafe(fancyTitle);
      } else {
        return payloadTitle;
      }
    } else {
      if (fancyTitle) {
        return htmlSafe(
          I18n.t("user_menu.reviewable.new_post_in_topic", {
            title: fancyTitle,
          })
        );
      } else {
        return I18n.t("user_menu.reviewable.new_post_in_topic", {
          title: payloadTitle,
        });
      }
    }
  }

  get icon() {
    return "layer-group";
  }
}
