import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import PostCookedHtml from "discourse/components/post/cooked-html";
import UserLink from "discourse/components/user-link";
import boundAvatarTemplate from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SolvedAcceptedAnswer extends Component {
  @service siteSettings;

  @tracked expanded = false;

  get topic() {
    return this.args.post.topic;
  }

  get acceptedAnswer() {
    return this.topic.accepted_answer;
  }

  get quoteId() {
    return `accepted-answer-${this.topic.id}-${this.acceptedAnswer.post_number}`;
  }

  get hasExcerpt() {
    return !!this.acceptedAnswer.excerpt;
  }

  get content() {
    if (!this.hasExcerpt) {
      return "";
    }

    return trustHTML(this.acceptedAnswer.excerpt);
  }

  get showMarkedBy() {
    return this.siteSettings.show_who_marked_solved;
  }

  get showSolvedBy() {
    return !(!this.acceptedAnswer.username || !this.acceptedAnswer.post_number);
  }

  get postNumber() {
    return i18n("solved.accepted_answer_post_number", {
      post_number: this.acceptedAnswer.post_number,
    });
  }

  get solverUsername() {
    return this.acceptedAnswer.username;
  }

  get accepterUsername() {
    return this.acceptedAnswer.accepter_username;
  }

  get solverDisplayName() {
    const username = this.acceptedAnswer.username;
    const name = this.acceptedAnswer.name;

    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  get accepterDisplayName() {
    const username = this.acceptedAnswer.accepter_username;
    const name = this.acceptedAnswer.accepter_name;

    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  get postPath() {
    const postNumber = this.acceptedAnswer.post_number;
    return `${this.topic.url}/${postNumber}`;
  }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
  }

  @action
  onClickTitle(event) {
    if (event.target.closest("a") || event.target.closest(".quote-controls")) {
      return;
    }
    this.toggleExpanded();
  }

  <template>
    {{! template-lint-disable no-unnecessary-concat }}
    {{#if this.acceptedAnswer}}
      <aside
        class={{concatClass
          "quote accepted-answer d-solved-answer"
          (if this.hasExcerpt "accepted-answer--has-excerpt")
          (unless this.content "title-only")
        }}
        data-expanded="{{this.expanded}}"
        data-username={{this.acceptedAnswer.username}}
        data-post={{this.acceptedAnswer.post_number}}
        data-topic={{this.topic.id}}
      >
        <div class="d-solved-answer__header">
          <h3 class="d-solved-answer__title">
            {{icon "far-square-check"}}
            {{i18n "solved.title"}}</h3>
          <div class="d-solved-answer__controls">
            {{#if this.content}}
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
            <DButton
              class="btn-flat d-solved-answer__jump"
              @href={{this.postPath}}
              @title="post.follow_quote"
              @ariaLabel="post.follow_quote"
              @icon="arrow-down"
            />
          </div>
        </div>

        {{#if this.content}}
          <blockquote id={{this.quoteId}}>
            <PostCookedHtml
              @post={{@post}}
              @cooked={{this.content}}
              @decoratorState={{@decoratorState}}
            />
          </blockquote>
        {{/if}}

        <div class="d-solved-answer__footer">
          {{#if this.showSolvedBy}}
            <UserLink @username={{this.solverUsername}}>
              {{boundAvatarTemplate this.acceptedAnswer.avatar_template "tiny"}}
            </UserLink>
            <InterpolatedTranslation
              @key="solved.accepted_answer_solver_info"
              as |Placeholder|
            >
              <Placeholder @name="user" @class="d-solved-answer__solver">
                {{this.solverDisplayName}}
              </Placeholder>
              <Placeholder @name="post">
                <a
                  class="d-solved-answer__post-link"
                  href={{this.postPath}}
                >{{this.postNumber}}</a>
              </Placeholder>
            </InterpolatedTranslation>
          {{/if}}
          {{#if this.showMarkedBy}}
            <span class="dot-separator"></span>

            <InterpolatedTranslation
              @key="solved.marked_solved_by"
              as |Placeholder|
            >
              <Placeholder @name="user" @class="d-solved-answer__accepter">
                {{this.accepterDisplayName}}
              </Placeholder>
            </InterpolatedTranslation>

          {{/if}}
        </div>
      </aside>
    {{/if}}
  </template>
}
