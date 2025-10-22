import getURL from "discourse/lib/get-url";
import { getRenderDirector } from "discourse/lib/reviewable-types-manager";
import UserMenuBaseItem from "discourse/lib/user-menu/base-item";

export default class UserMenuReviewableItem extends UserMenuBaseItem {
  constructor({ reviewable, currentUser, siteSettings, site }) {
    super(...arguments);
    this.reviewable = reviewable;
    this.currentUser = currentUser;
    this.siteSettings = siteSettings;
    this.site = site;

    this.renderDirector = getRenderDirector(
      this.reviewable.type,
      this.reviewable,
      this.currentUser,
      this.siteSettings,
      this.site
    );
  }

  get className() {
    const classes = ["reviewable"];
    if (this.reviewable.pending) {
      classes.push("pending");
    } else {
      classes.push("reviewed");
    }
    return classes.join(" ");
  }

  get linkHref() {
    return getURL(`/review/${this.reviewable.id}`);
  }

  get linkTitle() {
    // TODO(osama): add title
    return "";
  }

  get icon() {
    return this.renderDirector.icon;
  }

  get label() {
    return this.renderDirector.actor;
  }

  get description() {
    return this.renderDirector.description;
  }
}
