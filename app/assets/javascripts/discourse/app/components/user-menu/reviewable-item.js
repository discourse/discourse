import GlimmerComponent from "discourse/components/glimmer";
import { getRenderDirector } from "discourse/lib/reviewable-item";

export default class UserMenuReviewableItem extends GlimmerComponent {
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

  get actor() {
    return this.renderDirector.actor;
  }

  get description() {
    return this.renderDirector.description;
  }

  get icon() {
    return this.renderDirector.icon;
  }
}
