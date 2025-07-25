import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import ReviewableTopicLink from "discourse/components/reviewable-topic-link";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";
import ModelAccuracies from "./model-accuracies";

const ReviewableAiPost = <template>
  <div class="flagged-post-header">
    <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="" />
    <ReviewablePostEdits @reviewable={{@reviewable}} @tagName="" />
  </div>

  <div class="post-contents-wrapper">
    <ReviewableCreatedBy @user={{@reviewable.target_created_by}} @tagName="" />
    <div class="post-contents">
      <ReviewablePostHeader
        @reviewable={{@reviewable}}
        @createdBy={{@reviewable.target_created_by}}
        @tagName=""
      />
      <div class="post-body">
        {{#if @reviewable.blank_post}}
          <p>{{i18n "review.deleted_post"}}</p>
        {{else}}
          {{htmlSafe @reviewable.cooked}}
        {{/if}}
      </div>

      {{yield}}

      <ModelAccuracies @accuracies={{@reviewable.payload.accuracies}} />
    </div>
  </div>
</template>;

export default ReviewableAiPost;
