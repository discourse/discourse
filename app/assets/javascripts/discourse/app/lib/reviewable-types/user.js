import ReviewableTypeBase from "discourse/lib/reviewable-types/base";
import I18n from "I18n";

export default class extends ReviewableTypeBase {
  get description() {
    return I18n.t("user_menu.reviewable.suspicious_user", {
      username: this.reviewable.username,
    });
  }

  get icon() {
    return "user";
  }
}
