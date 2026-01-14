import { i18n } from "discourse-i18n";

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
      return i18n("user_menu.reviewable.deleted_user");
    }
  }

  get description() {
    return i18n("user_menu.reviewable.default_item", {
      reviewable_id: this.reviewable.id,
    });
  }

  get icon() {
    return "flag";
  }
}
