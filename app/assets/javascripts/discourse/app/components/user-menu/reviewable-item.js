import { getRenderDirector } from "discourse/lib/reviewable-item";
import UserMenuItemsListBaseItem from "discourse/components/user-menu/items-list-base-item";

export default class UserMenuReviewableItem extends UserMenuItemsListBaseItem {
  constructor({ reviewable, siteSettings, currentUser, site }) {
    super(...arguments);
    this.reviewable = reviewable;
    this.siteSettings = siteSettings;
    this.currentUser = currentUser;
    this.site = site;

    this.renderDirector = getRenderDirector(
      this.reviewable.type,
      this.reviewable,
      this.currentUser,
      this.siteSettings,
      this.site
    );
  }

  get classNames() {
    let classes = [];

    if (!this.reviewable.pending) {
      classes.push("reviewed");
    }

    return classes.join(" ");
  }

  get linkHref() {
    return `/review/${this.reviewable.id}`;
  }

  get linkTitle() {
    // Should implement something here
    return "";
  }

  get icon() {
    return this.renderDirector.icon;
  }

  get label() {
    return this.renderDirector.actor;
  }

  get labelWrapperClasses() {
    return "reviewable-label";
  }

  get description() {
    return this.renderDirector.description;
  }

  get descriptionWrapperClasses() {
    return "reviewable-description";
  }
}
