import Component from "@ember/component";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import ReviewableTopicLink from "discourse/components/reviewable-topic-link";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

export default class ReviewablePost extends Component {
  <template>
    <div class="flagged-post-header">
      <ReviewableTopicLink @reviewable={{this.reviewable}} @tagName="" />
      <ReviewablePostEdits @reviewable={{this.reviewable}} @tagName="" />
    </div>

    <div class="post-contents-wrapper">
      <ReviewableCreatedBy @user={{this.reviewable.target_created_by}} />
      <div class="post-contents">
        <ReviewablePostHeader
          @reviewable={{this.reviewable}}
          @createdBy={{this.reviewable.target_created_by}}
          @tagName=""
        />
        <div class="post-body">
          {{#if this.reviewable.blank_post}}
            <p>{{i18n "review.deleted_post"}}</p>
          {{else}}
            {{highlightWatchedWords this.reviewable.cooked this.reviewable}}
          {{/if}}
        </div>
        {{yield}}
      </div>
    </div>
  </template>
}
