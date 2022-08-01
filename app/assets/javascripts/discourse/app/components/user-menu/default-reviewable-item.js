import GlimmerComponent from "discourse/components/glimmer";
import I18n from "I18n";

export default class UserMenuReviewableItem extends GlimmerComponent {
  constructor() {
    super(...arguments);
    this.reviewable = this.args.item;
  }

  get actor() {
    const flagger = this.reviewable.flagger_username;
    if (flagger) {
      return flagger;
    } else {
      return I18n.t("user_menu.reviewable.deleted_user");
    }
  }

  get description() {
    return I18n.t("user_menu.reviewable.default_item", {
      reviewable_id: this.reviewable.id,
    });
  }

  get icon() {
    return "flag";
  }
}
