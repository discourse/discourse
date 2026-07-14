import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PostCookedHtml from "discourse/components/post/cooked-html";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { relativeAge } from "discourse/lib/formatter";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DRelativeDate from "discourse/ui-kit/d-relative-date";
import DUserLink from "discourse/ui-kit/d-user-link";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

export default class DPostAccordionItem extends Component {
  @service a11y;

  @tracked measured = false;
  @tracked isOverflowing = false;

  get post() {
    return this.args.post;
  }

  get quoteId() {
    return `post-accordion-item-${this.post.topic_id}-${this.post.post_number}`;
  }

  get hasContent() {
    return !!this.post?.cooked;
  }

  get srDate() {
    if (this.a11y.autoUpdatingRelativeDateRef && this.post.created_at) {
      return relativeAge(new Date(this.post.created_at), {
        format: "medium-with-ago",
        wrapInSpan: false,
      });
    }
  }

  get userDisplayName() {
    return userPrioritizedName({
      username: this.post.username,
      name: this.post.name,
    });
  }

  get maxHeightStyle() {
    if (this.args.linesDisplayed) {
      return trustHTML(`--max-lines-displayed: ${this.args.linesDisplayed}`);
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
      DiscourseURL.routeTo(this.post.url);
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
    {{#if this.post}}
      <div
        class={{dConcatClass
          "quote d-post-accordion-item"
          (if this.hasContent "d-post-accordion-item--has-content")
        }}
        style={{this.maxHeightStyle}}
        data-expanded={{@isExpanded}}
        data-overflowing={{this.overflowingAttr}}
        data-username={{this.post.username}}
        data-post={{this.post.post_number}}
        data-topic={{this.post.topic_id}}
      >
        {{! eslint-disable ember/template-no-invalid-interactive }}
        <div
          class="d-post-accordion-item__header"
          {{on "click" this.onClickHeader}}
        >
          <div class="d-post-accordion-item__metadata">
            {{#if @hasItemMetadataBlock}}
              {{yield this.post to="itemMetadata"}}
            {{else}}
              <DUserLink @username={{this.post.username}} class="user-link">
                {{dBoundAvatarTemplate this.post.avatar_template "tiny"}}
                <span>{{this.userDisplayName}}</span>
              </DUserLink>
              <span class="dot-separator"></span>
              <a
                href={{this.post.url}}
                class="date-link"
                title={{i18n "post.sr_date"}}
                aria-label={{this.srDate}}
              >
                <span aria-hidden="true">
                  <DRelativeDate @date={{this.post.created_at}} />
                </span>
              </a>
            {{/if}}
          </div>
          <div class="d-post-accordion-item__controls">
            {{#if this.hasContent}}
              <DButton
                class="btn-flat d-post-accordion-item__toggle"
                @action={{@onToggleExpanded}}
                @ariaExpanded={{@isExpanded}}
                @ariaLabel={{if @isExpanded "post.collapse" "expand"}}
                @title={{if @isExpanded "post.collapse" "expand"}}
                @icon={{if @isExpanded "chevron-up" "chevron-down"}}
              />
            {{else}}
              <DButton
                class="btn-flat d-post-accordion-item__jump"
                @href={{this.post.url}}
                @ariaLabel="post.follow_quote"
                @title="post.follow_quote"
                @icon="arrow-down"
              />
            {{/if}}
          </div>
        </div>

        {{#if this.hasContent}}
          <div class="d-post-accordion-item__body">
            <blockquote
              id={{this.quoteId}}
              class="d-post-accordion-item__content"
              {{dOnResize this.checkOverflow}}
            >
              {{#if @hasBeforeItemContentBlock}}
                {{yield this.post to="beforeItemContent"}}
              {{/if}}

              <PostCookedHtml
                @post={{this.post}}
                @decoratorState={{@decoratorState}}
              />

            </blockquote>

            <div class="d-post-accordion-item__read-more">
              <a href={{this.post.url}} class="read-more-link">
                {{i18n "read_more"}}
              </a>
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
