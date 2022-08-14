import ReviewableItemBase from "discourse/lib/reviewable-items/base";
import I18n from "I18n";

export default class extends ReviewableItemBase {
  get description() {
    return I18n.t("user_menu.reviewable.suspicious_user", {
      username: this.reviewable.username,
    });
  }

  get icon() {
    return "user";
  }
}
