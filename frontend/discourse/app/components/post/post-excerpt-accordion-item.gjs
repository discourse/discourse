import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import PostCookedHtml from "discourse/components/post/cooked-html";
import RelativeDate from "discourse/components/relative-date";
import UserLink from "discourse/components/user-link";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import onResize from "discourse/modifiers/on-resize";
import { i18n } from "discourse-i18n";

const DEFAULT_LINES_DISPLAYED = 6;

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

  get linesDisplayed() {
    return this.args.linesDisplayed || DEFAULT_LINES_DISPLAYED;
  }

  get maxHeightStyle() {
    return trustHTML(`--excerpt-max-lines: ${this.linesDisplayed}`);
  }

  get overflowingAttr() {
    return this.measured ? String(this.isOverflowing) : "true";
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
        class={{concatClass
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
        <div class="d-post-excerpt-accordion-item__header">
          <div class="d-post-excerpt-accordion-item__metadata">
            {{#if (has-block "itemMetadata")}}
              {{yield this.excerptPost to="itemMetadata"}}
            {{else}}
              <UserLink
                @username={{this.excerptPost.username}}
                class="user-link"
              >
                {{boundAvatarTemplate this.excerptPost.avatar_template "tiny"}}
                <span>{{this.userDisplayName}}</span>
              </UserLink>
              <span class="dot-separator"></span>
              <a
                href={{this.excerptPost.post_url}}
                title={{i18n "post.sr_date"}}
              >
                <RelativeDate @date={{this.excerptPost.created_at}} />
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
            {{/if}}
          </div>
        </div>

        <div class="d-post-excerpt-accordion-item__body">
          {{#if this.hasContent}}

            <blockquote
              id={{this.quoteId}}
              class="d-post-excerpt-accordion-item__content"
              {{onResize this.checkOverflow}}
            >
              {{#if (has-block "beforeItemContent")}}
                {{yield this.excerptPost to="beforeAccordionItemContent"}}
              {{/if}}

              <PostCookedHtml
                @post={{this.excerptPost}}
                @decoratorState={{@decoratorState}}
              />

            </blockquote>

            <div class="d-post-excerpt-accordion-item__read-more">
              <a href={{this.excerptPost.post_url}} class="read-more-link">
                {{i18n "read_more"}}
              </a>
            </div>

          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
