import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Displays contextual insights about a reviewable item, including AI confidence,
 * flag volume, user history, and moderation actions. Only shows relevant insights
 * based on available data.
 *
 * @component ReviewableInsights
 *
 * @param {Reviewable} reviewable - The reviewable object containing all review data
 */
export default class ReviewableInsights extends Component {
  /**
   * Returns array of review insight objects to display
   * @returns {Array<Object>} Array of insight configuration objects
   */
  get reviewInsights() {
    const insights = [];
    const reviewable = this.args.reviewable;
    const user = this.args.reviewable.target_created_by;

    // Flag volume insight
    insights.push({
      icon: "triangle-exclamation",
      label: i18n("review.insights.flag_volume"),
      description: i18n("review.insights.flagged_by_users", {
        count: reviewable?.reviewable_scores?.length || 0,
      }),
    });

    // Similar posts insight
    if (user.flags_agreed) {
      insights.push({
        icon: "clock-rotate-left",
        label: i18n("review.insights.similar_posts"),
        description: i18n("review.insights.flagged_in_timeframe", {
          count: user.user_stat.flags_agreed,
        }),
      });
    }

    // User activity insight
    const activities = [];

    if (Date.now() - Date.parse(user.created_at) < 7 * 24 * 60 * 60 * 1000) {
      activities.push(i18n("review.insights.activities.new_account"));
    }
    activities.push(
      i18n("review.insights.activities.trust_level", {
        trustLevelName: user.trustLevel.name,
      })
    );
    activities.push(
      i18n("review.insights.activities.posts", {
        count: user.post_count,
      })
    );
    insights.push({
      icon: "users",
      label: i18n("review.insights.user_activity"),
      description: activities.join(", "),
    });

    // Visibility insight
    if (!reviewable?.topic?.visible) {
      insights.push({
        icon: "far-eye-slash",
        label: i18n("review.insights.visibility"),
        description: i18n("review.insights.topic_unlisted"),
      });
    }

    return insights;
  }

  <template>
    <div class="review-insight">
      {{#each this.reviewInsights as |insight|}}
        <div class="review-insight__item">
          <div class="review-insight__icon">
            {{icon insight.icon}}
          </div>
          <div class="review-insight__content">
            <div class="review-insight__label">{{insight.label}}</div>
            <div
              class="review-insight__description"
            >{{insight.description}}</div>
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
