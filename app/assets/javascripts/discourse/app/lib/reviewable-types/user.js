import ReviewableTypeBase from "discourse/lib/reviewable-types/base";
import { i18n } from "discourse-i18n";

export default class extends ReviewableTypeBase {
  get description() {
    return i18n("user_menu.reviewable.user_requires_approval", {
      username: this.reviewable.username,
    });
  }

  get icon() {
    return "user";
  }
}
