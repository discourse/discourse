import Component from "@glimmer/component";
import DNavItem from "discourse/ui-kit/d-nav-item";

export default class AiReviewBulkNavItem extends Component {
  static shouldRender(args, { currentUser, siteSettings }) {
    return (
      currentUser?.staff &&
      siteSettings.ai_reviewable_action_suggestions_enabled
    );
  }

  <template>
    <DNavItem
      class="ai-review-bulk-nav-item"
      @icon="discourse-sparkles"
      @label="discourse_ai.review_bulk.title"
      @route="review.bulk"
    />
  </template>
}
