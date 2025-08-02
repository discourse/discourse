import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import ReviewablePostHeader from "discourse/components/reviewable-post-header";
import ReviewableTopicLink from "discourse/components/reviewable-topic-link";
import lazyHash from "discourse/helpers/lazy-hash";
import { bind } from "discourse/lib/decorators";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

export default class ReviewableFlaggedPost extends Component {
  @tracked isCollapsed = false;
  @tracked isLongPost = false;
  maxPostHeight = 300;

  @action
  toggleContent() {
    this.isCollapsed = !this.isCollapsed;
  }

  @bind
  calculatePostBodySize(element) {
    if (element?.offsetHeight > this.maxPostHeight) {
      this.isCollapsed = true;
      this.isLongPost = true;
    } else {
      this.isCollapsed = false;
      this.isLongPost = false;
    }
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

  <template>
    <div class="flagged-post-header">
      <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="" />
      <ReviewablePostEdits @reviewable={{@reviewable}} @tagName="" />
    </div>

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
          {{didInsert this.calculatePostBodySize @reviewable}}
        >
          {{#if @reviewable.blank_post}}
            <p>{{i18n "review.deleted_post"}}</p>
          {{else}}
            {{highlightWatchedWords @reviewable.cooked @reviewable}}
          {{/if}}
        </div>

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
            @name="after-reviewable-flagged-post-body"
            @connectorTagName="div"
            @outletArgs={{lazyHash model=@reviewable}}
          />
        </span>
        {{yield}}
      </div>
    </div>
  </template>
}
