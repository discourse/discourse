import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CookText from "discourse/components/cook-text";
import DButton from "discourse/components/d-button";
import RawEmailModal from "discourse/components/modal/raw-email";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import ReviewableTags from "discourse/components/reviewable-tags";
import categoryBadge from "discourse/helpers/category-badge";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

export default class ReviewableQueuedPost extends Component {
  @service modal;

  @tracked isCollapsed = false;
  @tracked isLongPost = false;
  @tracked postBodyHeight = 0;
  maxPostHeight = 300;

  @action
  showRawEmail(event) {
    event?.preventDefault();
    this.modal.show(RawEmailModal, {
      model: {
        rawEmail: this.args.reviewable.payload.raw_email,
      },
    });
  }

  @action
  toggleContent() {
    this.isCollapsed = !this.isCollapsed;
  }

  get collapseButtonProps() {
    if (this.isCollapsed) {
      return {
        label: "review.show_more",
        icon: "chevron-down",
      };
    }
    return {
      label: "review.show_less",
      icon: "chevron-up",
    };
  }

  @action
  setPostBodyHeight(offsetHeight) {
    this.postBodyHeight = offsetHeight;

    if (this.postBodyHeight > this.maxPostHeight) {
      this.isCollapsed = true;
      this.isLongPost = true;
    } else {
      this.isCollapsed = false;
      this.isLongPost = false;
    }
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{i18n "review.new_topic_label"}}</div>

      <div class="review-item__meta-topic-title">
        <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="">
          <div class="title-text">
            {{icon "square-plus" title="review.new_topic"}}
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
    </div>

    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{i18n "review.queued_user"}}</div>

      <div class="review-item__meta-flagged-user">
        <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
      </div>
    </div>

    <div class="review-item__post">
      <div class="review-item__post-content">
        <ReviewablePostHeader
          @reviewable={{@reviewable}}
          @createdBy={{@reviewable.target_created_by}}
          @tagName=""
        />

        <CookText
          class="post-body {{if this.isCollapsed 'is-collapsed'}}"
          @rawText={{highlightWatchedWords @reviewable.payload.raw @reviewable}}
          @categoryId={{@reviewable.category_id}}
          @topicId={{@reviewable.topic_id}}
          @paintOneboxes={{true}}
          @opts={{hash removeMissing=true}}
          @onOffsetHeightCalculated={{this.setPostBodyHeight}}
        />

        {{#if this.isLongPost}}
          <DButton
            @action={{this.toggleContent}}
            @label={{this.collapseButtonProps.label}}
            @icon={{this.collapseButtonProps.icon}}
            class="btn-default btn-icon post-body__toggle-btn"
          />
        {{/if}}

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