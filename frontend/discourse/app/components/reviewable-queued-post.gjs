import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import RawEmailModal from "discourse/components/modal/raw-email";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import ReviewableTags from "discourse/components/reviewable-tags";
import ReviewableTopicLink from "discourse/components/reviewable-topic-link";
import categoryBadge from "discourse/helpers/category-badge";
import icon from "discourse/helpers/d-icon";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";

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
  setPostBodyHeight(element) {
    this.postBodyHeight = element.offsetHeight;

    if (this.postBodyHeight > this.maxPostHeight) {
      this.isCollapsed = true;
      this.isLongPost = true;
    } else {
      this.isCollapsed = false;
      this.isLongPost = false;
    }
  }

  <template>
    <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="">
      <div class="title-text">
        {{icon "square-plus" title="review.new_topic"}}
        {{highlightWatchedWords @reviewable.fancy_title @reviewable}}
      </div>
      {{categoryBadge @reviewable.category}}
      <ReviewableTags @tags={{@reviewable.payload.tags}} />
      {{#if @reviewable.payload.via_email}}
        <a href {{on "click" this.showRawEmail}} class="show-raw-email">
          {{icon "envelope" title="post.via_email"}}
        </a>
      {{/if}}
    </ReviewableTopicLink>

    <div class="post-contents-wrapper">
      <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />

      <div class="post-contents">
        <ReviewablePostHeader
          @reviewable={{@reviewable}}
          @createdBy={{@reviewable.target_created_by}}
          @tagName=""
        />

        <div
          class="post-body {{if this.isCollapsed 'is-collapsed'}}"
          {{didInsert this.setPostBodyHeight}}
        >
          {{highlightWatchedWords @reviewable.cooked @reviewable}}
        </div>

        {{#if this.isLongPost}}
          <DButton
            @action={{this.toggleContent}}
            @label={{this.collapseButtonProps.label}}
            @icon={{this.collapseButtonProps.icon}}
            class="btn-default btn-icon post-body__toggle-btn"
          />
        {{/if}}

        {{yield}}
      </div>
    </div>
  </template>
}
