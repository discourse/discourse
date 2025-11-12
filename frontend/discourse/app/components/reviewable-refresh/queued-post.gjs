import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CookText from "discourse/components/cook-text";
import RawEmailModal from "discourse/components/modal/raw-email";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableCreatedBy from "discourse/components/reviewable-refresh/created-by";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import ReviewableTags from "discourse/components/reviewable-tags";
import categoryBadge from "discourse/helpers/category-badge";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
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
        <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="">
          <div class="title-text">
            {{highlightWatchedWords @reviewable.payload.title @reviewable}}
          </div>
          {{categoryBadge @reviewable.category}}
          <ReviewableTags @tags={{@reviewable.payload.tags}} @tagName="" />
          {{#if @reviewable.payload.via_email}}
            <a href {{on "click" this.showRawEmail}} class="show-raw-email">
              {{icon "envelope" title="post.via_email"}}
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
        <CookText
          class="post-body"
          @rawText={{highlightWatchedWords @reviewable.payload.raw @reviewable}}
          @categoryId={{@reviewable.category_id}}
          @topicId={{@reviewable.topic_id}}
          @paintOneboxes={{true}}
          @opts={{hash removeMissing=true}}
        />

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
