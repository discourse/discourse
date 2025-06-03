import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ReviewableInsights = <template>
  <div class="review-insight">
    <div class="review-insight__item">
      <div class="review-insight__icon">
        {{icon "discourse-sparkles"}}
      </div>
      <div class="review-insight__content">
        <div class="review-insight__label">{{i18n
            "review.insights.ai_confidence"
          }}</div>
        <div class="review-insight__description">{{i18n
            "review.insights.spam_probability"
            percentage="85"
          }}</div>
      </div>
    </div>

    <div class="review-insight__item">
      <div class="review-insight__icon">
        {{icon "triangle-exclamation"}}
      </div>
      <div class="review-insight__content">
        <div class="review-insight__label">{{i18n
            "review.insights.flag_volume"
          }}</div>
        <div class="review-insight__description">{{i18n
            "review.insights.flagged_by_users"
            count=@reviewable.reviewable_scores.length
          }}</div>
      </div>
    </div>

    <div class="review-insight__item">
      <div class="review-insight__icon">
        {{icon "clock-rotate-left"}}
      </div>
      <div class="review-insight__content">
        <div class="review-insight__label">{{i18n
            "review.insights.similar_posts"
          }}</div>
        <div class="review-insight__description">{{i18n
            "review.insights.flagged_in_timeframe"
            count="3"
            timeframe="6 months"
          }}</div>
      </div>
    </div>

    <div class="review-insight__item">
      <div class="review-insight__icon">
        {{icon "gavel"}}
      </div>
      <div class="review-insight__content">
        <div class="review-insight__label">{{i18n
            "review.insights.mod_actions"
          }}</div>
        <div class="review-insight__description">{{i18n
            "review.insights.past_actions"
            suspended="1"
            silenced="1"
          }}</div>
      </div>
    </div>

    <div class="review-insight__item">
      <div class="review-insight__icon">
        {{icon "users"}}
      </div>
      <div class="review-insight__content">
        <div class="review-insight__label">{{i18n
            "review.insights.user_activity"
          }}</div>
        <div class="review-insight__description">{{i18n
            "review.insights.new_account_low_trust"
          }}</div>
      </div>
    </div>

    {{#if @reviewable.topic.has_accepted_answer}}
      <div class="review-insight__item">
        <div class="review-insight__icon">
          {{icon "circle-check"}}
        </div>
        <div class="review-insight__content">
          <div class="review-insight__label">{{i18n
              "review.insights.solution_marked"
            }}</div>
          <div class="review-insight__description">{{i18n
              "review.insights.topic_has_solution"
            }}</div>
        </div>
      </div>
    {{/if}}

    {{#if @reviewable.topic.visible}}{{else}}
      <div class="review-insight__item">
        <div class="review-insight__icon">
          {{icon "far-eye-slash"}}
        </div>
        <div class="review-insight__content">
          <div class="review-insight__label">{{i18n
              "review.insights.visibility"
            }}</div>
          <div class="review-insight__description">{{i18n
              "review.insights.topic_unlisted"
            }}</div>
        </div>
      </div>
    {{/if}}
  </div>
</template>;

export default ReviewableInsights;
