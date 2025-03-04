import Component from "@ember/component";
import { concat } from "@ember/helper";
import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";

export default class ReviewablePostHeader extends Component {
  <template>
    <div class="reviewable-post-header">
      <ReviewableCreatedByName @user={{this.createdBy}} />
      {{#if this.reviewable.reply_to_post_number}}
        <a
          href={{concat
            this.reviewable.topic_url
            "/"
            this.reviewable.reply_to_post_number
          }}
          class="reviewable-reply-to"
        >
          {{dIcon "share"}}
          <span>{{iN "review.in_reply_to"}}</span>
        </a>
      {{/if}}
    </div>
  </template>
}
