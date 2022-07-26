import UserMenuDefaultReviewableItem from "discourse/components/user-menu/default-reviewable-item";
import I18n from "I18n";

export default class UserMenuReviewableUserItem extends UserMenuDefaultReviewableItem {
  get description() {
    return I18n.t("user_menu.reviewable.suspicious_user", {
      username: this.reviewable.username,
    });
  }

  get icon() {
    return "user";
  }
}
