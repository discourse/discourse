import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import PostCookedHtml from "discourse/components/post/cooked-html";
import RelativeDate from "discourse/components/relative-date";
import UserLink from "discourse/components/user-link";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { i18n } from "discourse-i18n";

export default class PostExcerptAccordionItem extends Component {
  get excerptPost() {
    return this.args.excerptPost;
  }

  get topic() {
    return this.excerptPost.topic;
  }

  get quoteId() {
    return `post-excerpt-${this.topic.id}-${this.excerptPost.post_number}`;
  }

  get hasContent() {
    return !!this.excerptPost?.cooked;
  }

  get postPath() {
    return `${this.topic.url}/${this.excerptPost.post_number}`;
  }

  get userDisplayName() {
    return userPrioritizedName(this.excerptPost.user);
  }

  <template>
    {{#if this.excerptPost}}
      <div
        class={{concatClass
          "quote d-post-excerpt-accordion-item"
          (if this.hasContent "d-post-excerpt-accordion-item--has-excerpt")
          (unless this.hasContent "title-only")
        }}
        data-expanded={{@isExpanded}}
        data-username={{this.excerptPost.user.username}}
        data-post={{this.excerptPost.post_number}}
        data-topic={{this.topic.id}}
      >
        <div class="d-post-excerpt-accordion-item__header">
          <div class="d-post-excerpt-accordion-item__metadata">
            {{#if (has-block "accordionItemMetadata")}}
              {{yield this.excerptPost to="accordionItemMetadata"}}
            {{else}}
              <UserLink @user={{this.excerptPost.user}}>
                {{boundAvatarTemplate
                  this.excerptPost.user.avatar_template
                  "tiny"
                }}
                <span>
                  {{this.userDisplayName}}
                </span>
              </UserLink>
              <span class="dot-separator"></span>
              <a
                href={{this.excerptPost.post_url}}
                title={{i18n "post.sr_date"}}
              >
                <RelativeDate @date={{this.excerptPost.displayDate}} />
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
            >
              {{#if (has-block "beforeAccordionItemContent")}}
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
