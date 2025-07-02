import Component from "@glimmer/component";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import ReviewableFlagReason from "discourse/components/reviewable-refresh/flag-reason";
import { i18n } from "discourse-i18n";

export default class ReviewableItem extends Component {
  @service siteSettings;

  get customClasses() {
    const type = this.args.reviewable.type;
    const lastPerformingUsername =
      this.args.reviewable.last_performing_username;
    const blurEnabled = this.siteSettings.blur_tl0_flagged_posts_media;
    const trustLevel = this.args.reviewable.target_created_by_trust_level;

    let classes = dasherize(type);

    if (lastPerformingUsername) {
      classes = `${classes} reviewable-stale`;
    }

    if (blurEnabled && trustLevel === 0) {
      classes = `${classes} blur-images`;
    }

    return classes;
  }

  get scoreSummary() {
    const scores = this.args.reviewable.reviewable_scores || [];

    const scoreData = scores.reduce((acc, score) => {
      if (!acc[score.score_type.type]) {
        acc[score.score_type.type] = {
          title: score.score_type.title,
          type: score.score_type.type,
          count: 0,
        };
      }

      acc[score.score_type.type].count += 1;
      return acc;
    }, {});

    return Object.values(scoreData);
  }

  <template>
    <div class="review-container">
      <div
        class="review-item {{this.customClasses}}"
        data-reviewable-id={{@reviewable.id}}
      >
        <div class="review-item__primary-content">
          <div class="review-item__flag-summary">
            <div class="review-item__header">
              <div class="review-item__label-badges">
                <span class="review-item__flag-label">{{i18n
                    "review.flagged_as"
                  }}</span>

                <div class="review-item__flag-badges">
                  {{#each this.scoreSummary as |score|}}
                    <ReviewableFlagReason
                      @type={{score.type}}
                      @title={{score.title}}
                      @count={{score.count}}
                    />
                  {{/each}}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </template>
}
