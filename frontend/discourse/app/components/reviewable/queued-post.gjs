import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RawEmailModal from "discourse/components/modal/raw-email";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableCreatedBy from "discourse/components/reviewable/created-by";
import ReviewableTopicLink from "discourse/components/reviewable/topic-link";
import ReviewableTags from "discourse/components/reviewable-tags";
import lazyHash from "discourse/helpers/lazy-hash";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ReviewableQueuedPost extends Component {
  @service modal;

  @action
  showRawEmail(event) {
    event?.preventDefault();
    this.modal.show(RawEmailModal, {
      model: {
        rawEmail: this.args.reviewable.payload.raw_email,
      },
    });
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{i18n "review.topic_label"}}</div>

      <div class="review-item__meta-topic-title">
        <ReviewableTopicLink @reviewable={{@reviewable}}>
          <div class="title-text">
            {{highlightWatchedWords @reviewable.fancy_title @reviewable}}
          </div>
          {{dCategoryBadge @reviewable.category}}
          <ReviewableTags @tags={{@reviewable.payload.tags}} />
          {{#if @reviewable.payload.via_email}}
            <a href {{on "click" this.showRawEmail}} class="show-raw-email">
              {{dIcon "envelope" title="post.via_email"}}
            </a>
          {{/if}}
        </ReviewableTopicLink>
      </div>

      <div class="review-item__meta-label">{{i18n "review.review_user"}}</div>

      <div class="review-item__meta-flagged-user">
        <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
      </div>
    </div>

    <div class="review-item__post">
      <div class="review-item__post-content">
        <div class="post-body">
          {{highlightWatchedWords @reviewable.cooked @reviewable}}
        </div>

        <span>
          <PluginOutlet
            @name="after-reviewable-queued-post-body"
            @connectorTagName="div"
            @outletArgs={{lazyHash model=@reviewable}}
          />
        </span>

        {{yield}}
      </div>
    </div>
  </template>
}
