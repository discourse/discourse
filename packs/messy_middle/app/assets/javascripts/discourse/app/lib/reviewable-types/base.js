import I18n from "I18n";

export default class ReviewableTypeBase {
  constructor({ reviewable, currentUser, siteSettings, site }) {
    this.reviewable = reviewable;
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;
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
