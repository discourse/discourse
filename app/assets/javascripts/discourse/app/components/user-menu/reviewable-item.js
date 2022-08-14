import UserMenuItem from "discourse/components/user-menu/menu-item";
import getURL from "discourse-common/lib/get-url";
import { getRenderDirector } from "discourse/lib/reviewable-item";
import { inject as service } from "@ember/service";

export default class UserMenuReviewableItem extends UserMenuItem {
  @service currentUser;
  @service siteSettings;
  @service site;

  constructor() {
    super(...arguments);
    this.reviewable = this.args.item;
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
