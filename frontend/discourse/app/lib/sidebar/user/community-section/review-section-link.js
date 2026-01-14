import BaseSectionLink from "discourse/lib/sidebar/base-community-section-link";
import { getReviewBadgeText } from "discourse/lib/sidebar/helpers/review-badge-helper";
import { i18n } from "discourse-i18n";

export default class ReviewSectionLink extends BaseSectionLink {
  get shouldDisplay() {
    return !!this.currentUser?.can_review;
  }

  get name() {
    return "review";
  }

  get route() {
    return "review";
  }

  get title() {
    return i18n("sidebar.sections.community.links.review.title");
  }

  get text() {
    return i18n(
      `sidebar.sections.community.links.${this.overriddenName.toLowerCase()}.content`,
      { defaultValue: this.overriddenName }
    );
  }

  get badgeText() {
    return getReviewBadgeText(this.currentUser);
  }

  get defaultPrefixValue() {
    return "flag";
  }
}
