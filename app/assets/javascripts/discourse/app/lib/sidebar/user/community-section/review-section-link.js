import I18n from "I18n";

import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";

export default class ReviewSectionLink extends BaseSectionLink {
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
    return this.currentUser.can_review;
  }

  get badgeText() {
    if (this.currentUser.reviewable_count > 0) {
      return I18n.t("sidebar.sections.community.links.review.pending_count", {
        count: this.currentUser.reviewable_count,
      });
    }
  }
}
