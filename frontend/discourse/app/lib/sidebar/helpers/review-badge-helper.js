import { i18n } from "discourse-i18n";

export function getReviewBadgeText(currentUser) {
  // force a tracker for reviewable_count by using .get to ensure badgeText
  // rerenders when reviewable_count changes
  if (currentUser?.get("reviewable_count") > 0) {
    return i18n("sidebar.sections.community.links.review.pending_count", {
      count: currentUser.reviewable_count,
    });
  }
}
