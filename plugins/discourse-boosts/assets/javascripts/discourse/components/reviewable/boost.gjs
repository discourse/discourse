import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import ReviewableCreatedBy from "discourse/components/reviewable/created-by";
import ReviewableTopicLink from "discourse/components/reviewable/topic-link";
import { i18n } from "discourse-i18n";

export default class ReviewableBoost extends Component {
  get boostCooked() {
    return this.args.reviewable.payload?.boost_cooked;
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{i18n
          "discourse_boosts.reviewable.boost_on_post"
        }}</div>

      <div class="review-item__meta-topic-title">
        <ReviewableTopicLink @reviewable={{@reviewable}} />
      </div>

      <div class="review-item__meta-label">{{i18n "review.review_user"}}</div>

      <div class="review-item__meta-flagged-user">
        <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
      </div>
    </div>

    <div class="review-item__post">
      <div class="review-item__post-content-wrapper">
        <div class="review-item__post-content">
          {{htmlSafe this.boostCooked}}
          {{yield}}
        </div>
      </div>
    </div>
  </template>
}
