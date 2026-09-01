import ReviewableCreatedBy from "discourse/components/reviewable/created-by";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="review-item__meta-content">
    <div class="review-item__meta-label">{{i18n
        "voice.review.flagged_in"
      }}</div>

    <div class="review-item__meta-topic-title">
      <a href={{getURL @reviewable.room_url}}>{{@reviewable.room_name}}</a>
    </div>

    <div class="review-item__meta-label">{{i18n "review.review_user"}}</div>

    <div class="review-item__meta-flagged-user">
      <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
    </div>
  </div>

  <div class="review-item__post">
    <div class="review-item__post-content-wrapper">
      <div class="review-item__post-content">
        {{@reviewable.message}}
        {{yield}}
      </div>
    </div>
  </div>
</template>
