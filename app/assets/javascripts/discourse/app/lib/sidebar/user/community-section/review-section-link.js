import I18n from "I18n";

import { tracked } from "@glimmer/tracking";

import { bind } from "discourse-common/utils/decorators";
import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

export default class ReviewSectionLink extends BaseSectionLink {
  @tracked canDisplay;

  constructor() {
    super(...arguments);

    this._refreshCanDisplay();
    this.appEvents.on("user-reviewable-count:changed", this._refreshCanDisplay);
  }

  teardown() {
    this.appEvents.off(
      "user-reviewable-count:changed",
      this._refreshCanDisplay
    );
  }

  @bind
  _refreshCanDisplay() {
    if (!this.currentUser.can_review) {
      this.canDisplay = false;
    }

    if (this.inMoreDrawer) {
      this.canDisplay = this.currentUser.reviewable_count < 1;
    } else {
      this.canDisplay = this.currentUser.reviewable_count > 0;
    }
  }

  get name() {
    return "review";
  }

  get route() {
    return "review";
  }

  get title() {
    return I18n.t("sidebar.sections.community.links.review.title");
  }

  get text() {
    return I18n.t("sidebar.sections.community.links.review.content");
  }

  get shouldDisplay() {
    return this.canDisplay;
  }

  get badgeText() {
    if (this.currentUser.reviewable_count > 0) {
      return I18n.t("sidebar.sections.community.links.review.pending_count", {
        count: this.currentUser.reviewable_count,
      });
    }
  }

  get prefixValue() {
    return "flag";
  }
}
