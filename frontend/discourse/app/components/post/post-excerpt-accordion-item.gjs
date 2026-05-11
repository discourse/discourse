import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import PostCookedHtml from "discourse/components/post/cooked-html";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import DUserLink from "discourse/ui-kit/d-user-link";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

export default class PostExcerptAccordionItem extends Component {
  @tracked measured = false;
  @tracked isOverflowing = false;

  get excerptPost() {
    return this.args.excerptPost;
  }

  get quoteId() {
    return `post-excerpt-${this.excerptPost.topic_id}-${this.excerptPost.post_number}`;
  }

  get hasContent() {
    return !!this.excerptPost?.cooked;
  }

  get postPath() {
    return this.excerptPost.post_url;
  }

  get userDisplayName() {
    return userPrioritizedName({
      username: this.excerptPost.username,
      name: this.excerptPost.name,
    });
  }

  get maxHeightStyle() {
    if (this.args.linesDisplayed) {
      return trustHTML(`--excerpt-max-lines: ${this.args.linesDisplayed}`);
    }
  }

  get overflowingAttr() {
    return this.measured ? String(this.isOverflowing) : "true";
  }

  @action
  onClickHeader(event) {
    if (event.target.closest("a")) {
      return;
    }

    if (this.hasContent) {
      this.args.onToggleExpanded();
    } else {
      DiscourseURL.routeTo(this.postPath);
    }
  }

  @action
  checkOverflow(entries) {
    if (!this.args.isExpanded) {
      this.isOverflowing = false;
      this.measured = true;
    }

    const blockquote = entries?.[0]?.target;
    if (!blockquote) {
      return;
    }

    this.isOverflowing = blockquote.scrollHeight > blockquote.clientHeight + 1;
    this.measured = true;
  }

  <template>
    {{#if this.excerptPost}}
      <div
        class={{dConcatClass
          "quote d-post-excerpt-accordion-item"
          (if this.hasContent "d-post-excerpt-accordion-item--has-excerpt")
          (unless this.hasContent "title-only")
        }}
        style={{this.maxHeightStyle}}
        data-expanded={{@isExpanded}}
        data-overflowing={{this.overflowingAttr}}
        data-username={{this.excerptPost.user.username}}
        data-post={{this.excerptPost.post_number}}
        data-topic={{this.topic.id}}
      >
        {{! template-lint-disable no-invalid-interactive }}
        <div
          class="d-post-excerpt-accordion-item__header"
          {{on "click" this.onClickHeader}}
        >
          <div class="d-post-excerpt-accordion-item__metadata">
            {{#if @hasItemMetadataBlock}}
              {{yield this.excerptPost to="itemMetadata"}}
            {{else}}
              <DUserLink
                @username={{this.excerptPost.username}}
                class="user-link"
              >
                {{dBoundAvatarTemplate this.excerptPost.avatar_template "tiny"}}
                <span>{{this.userDisplayName}}</span>
              </DUserLink>
              <span class="dot-separator"></span>
              <a
                href={{this.excerptPost.post_url}}
                title={{i18n "post.sr_date"}}
              >
                <DRelativeDate @date={{this.excerptPost.created_at}} />
              </a>
            {{/if}}
          </div>
          <div class="d-post-excerpt-accordion-item__controls">
            {{#if this.hasContent}}
              <DButton
                class="btn-flat d-post-excerpt-accordion-item__toggle"
                @action={{@onToggleExpanded}}
                @ariaControls={{this.quoteId}}
                @ariaExpanded={{@isExpanded}}
                @ariaLabel={{if @isExpanded "post.collapse" "expand"}}
                @title={{if @isExpanded "post.collapse" "expand"}}
                @icon={{if @isExpanded "chevron-up" "chevron-down"}}
              />
            {{else}}
              <DButton
                class="btn-flat d-post-excerpt-accordion-item__jump"
                @href={{this.postPath}}
                @ariaLabel="post.follow_quote"
                @title="post.follow_quote"
                @icon="arrow-down"
              />
            {{/if}}
          </div>
        </div>

        {{#if this.hasContent}}
          <div class="d-post-excerpt-accordion-item__body">
            <blockquote
              id={{this.quoteId}}
              class="d-post-excerpt-accordion-item__content"
              {{dOnResize this.checkOverflow}}
            >
              {{#if @hasBeforeItemContentBlock}}
                {{yield this.excerptPost to="beforeItemContent"}}
              {{/if}}

              <PostCookedHtml
                @post={{this.excerptPost}}
                @decoratorState={{@decoratorState}}
              />

            </blockquote>

            <div class="d-post-excerpt-accordion-item__read-more">
              <a href={{this.excerptPost.url}} class="read-more-link">
                {{i18n "read_more"}}
              </a>
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
