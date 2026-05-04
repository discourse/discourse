import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
//import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PostCookedHtml from "discourse/components/post/cooked-html";
import RelativeDate from "discourse/components/relative-date";
import UserLink from "discourse/components/user-link";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { i18n } from "discourse-i18n";

export default class PostExcerptAccordionItem extends Component {
  //@service siteSettings;

  @tracked expanded = false;

  get excerptPost() {
    return this.args.excerptPost;
  }

  get topic() {
    return this.args.post.topic;
  }

  get quoteId() {
    return `post-excerpt-${this.topic.id}-${this.postExcerpt.post_number}`;
  }

  // get hasExcerpt() {
  //   return !!this.excerptPost.cooked;
  // }

  get hasContent() {
    return !!this.postExcerpt?.cooked;
  }

  // get showMarkedBy() {
  //   return this.siteSettings.show_who_marked_solved;
  // }

  // get showSolvedBy() {
  //   return !(!this.answer.username || !this.answer.post_number);
  // }

  get postPath() {
    return `${this.topic.url}/${this.excerptPost.post_number}`;
  }

  get userDisplayName() {
    return userPrioritizedName(this.excerptPost.user);
  }

  // get accepterDisplayName() {
  //   const username = this.answer.accepter_username;
  //   const name = this.answer.accepter_name;
  //   return this.siteSettings.display_name_on_posts && name ? name : username;
  // }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
  }

  <template>
    {{#if this.excerptPost}}
      <div
        class={{concatClass
          "quote d-post-excerpt-accordion-item"
          (if this.hasContent "d-post-excerpt-accordion-item--has-excerpt")
          (unless this.hasContent "title-only")
        }}
        data-expanded={{this.expanded}}
        data-username={{this.excerptPost.user.username}}
        data-post={{this.excerptPost.post_number}}
        data-topic={{this.topic.id}}
      >
        <div class="d-post-excerpt-accordion-item__header">
          <div class="d-post-excerpt-accordion-item__metadata">
            {{#if (has-block "accordionItemMetadata")}}
              {{yield
                (hash excerptPost=this.excerptPost)
                to="accordionItemMetadata"
              }}
            {{else}}
              <UserLink @user={{this.excerptPost.user}}>
                {{boundAvatarTemplate
                  this.excerptPost.user.avatar_template
                  "tiny"
                }}
              </UserLink>
              <span>
                {{this.userDisplayName}}
              </span>
              <span class="dot-separator"></span>
              <a
                href={{this.excerptPost.post_url}}
                title={{i18n "post.sr_date"}}
              >
                <RelativeDate @date={{@statusPost.displayDate}} />
              </a>
            {{/if}}
          </div>
          <div class="d-solved-answer__controls">
            {{#if this.hasContent}}
              <DButton
                class="btn-flat d-solved-answer__toggle"
                @action={{this.toggleExpanded}}
                @ariaControls={{this.quoteId}}
                @ariaExpanded={{this.expanded}}
                @ariaLabel={{if this.expanded "post.collapse" "expand"}}
                @title={{if this.expanded "post.collapse" "expand"}}
                @icon={{if this.expanded "chevron-up" "chevron-down"}}
              />
            {{/if}}
          </div>
        </div>

        {{#if this.hasContent}}
          <blockquote
            id={{this.quoteId}}
            class="d-post-excerpt-accordion-item__content"
          >
            <PostCookedHtml
              @post={{this.excerptPost}}
              @decoratorState={{@decoratorState}}
            />
          </blockquote>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
