import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import IpLookup from "discourse/components/reviewable-refresh/ip-lookup";
import { shortDate } from "discourse/lib/formatter";
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
    const flagCount = reviewable?.reviewable_scores?.length || 0;
    if (flagCount > 1) {
      insights.push({
        icon: "triangle-exclamation",
        label: i18n("review.insights.flag_volume"),
        description: i18n("review.insights.flagged_by_users", {
          count: flagCount,
        }),
      });
    }

    // Similar posts insight
    if (user?.flags_agreed) {
      insights.push({
        icon: "clock-rotate-left",
        label: i18n("review.insights.similar_posts"),
        description: i18n("review.insights.flagged_in_timeframe", {
          count: user.user_stat?.flags_agreed || 0,
        }),
      });
    }

    // User activity insight
    const activities = [];

    if (user) {
      if (user.trustLevel) {
        activities.push(
          i18n("review.insights.activities.trust_level", {
            trustLevelName: user.trustLevel.name,
          })
        );
      }
      activities.push(
        i18n("review.insights.activities.joined_on", {
          joinDate: shortDate(user.created_at),
        })
      );
    }

    const postCount = user?.post_count || 0;
    const postsText = i18n("review.insights.activities.posts", {
      count: postCount,
    });

    if (postCount > 0 && user?.username) {
      activities.push(
        `<a href="/u/${user.username}/activity">${postsText}</a>`
      );
    } else {
      activities.push(postsText);
    }

    if (user?.email) {
      activities.push(user.email);
    }

    insights.push({
      icon: "users",
      label: i18n("review.insights.user_activity"),
      description: htmlSafe(activities.join(", ")),
    });

    // Visibility insight
    if (reviewable?.topic && !reviewable?.topic?.visible) {
      insights.push({
        icon: "far-eye-slash",
        label: i18n("review.insights.visibility"),
        description: i18n("review.insights.topic_unlisted"),
      });
    }

    const moderationActions = [
      i18n("review.insights.moderation_history.silenced", {
        count: user.silenced_count,
      }),
      i18n("review.insights.moderation_history.suspended", {
        count: user.suspended_count,
      }),
      i18n("review.insights.moderation_history.rejected_posts", {
        count: user.rejected_posts_count,
      }),
    ];
    insights.push({
      label: i18n("review.insights.moderation_history.label"),
      description: moderationActions.join(", "),
    });

    return insights;
  }

  <template>
    <div class="review-insight">
      {{#each this.reviewInsights as |insight|}}
        <div class="review-insight__item">
          <div class="review-insight__content">
            <div class="review-insight__label">{{insight.label}}</div>
            <div class="review-insight__description">
              {{insight.description}}
            </div>
          </div>
        </div>
      {{/each}}
      <IpLookup @reviewable={{@reviewable}} />
    </div>
  </template>
}
