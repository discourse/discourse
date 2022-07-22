import UserMenuDefaultReviewableItem from "discourse/components/user-menu/default-reviewable-item";
import I18n from "I18n";

export default class UserMenuReviewableUserItem extends UserMenuDefaultReviewableItem {
  get description() {
    const username = this.reviewable.username;
    return I18n.t("user_menu.reviewable.suspicious_user", { username });
  }

  get icon() {
    return "user";
  }
}
