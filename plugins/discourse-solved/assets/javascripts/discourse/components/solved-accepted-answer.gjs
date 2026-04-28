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

  get answer() {
    return this.args.answer;
  }

  get topic() {
    return this.args.topic;
  }

  get quoteId() {
    return `accepted-answer-${this.topic.id}-${this.answer.post_number}`;
  }

  get hasExcerpt() {
    return !!this.answer.excerpt;
  }

  get content() {
    return this.hasExcerpt ? trustHTML(this.answer.excerpt) : "";
  }

  get showMarkedBy() {
    return this.siteSettings.show_who_marked_solved;
  }

  get showSolvedBy() {
    return !(!this.answer.username || !this.answer.post_number);
  }

  get postNumber() {
    return i18n("solved.accepted_answer_post_number", {
      post_number: this.answer.post_number,
    });
  }

  get postPath() {
    return `${this.topic.url}/${this.answer.post_number}`;
  }

  get solverDisplayName() {
    const { username, name } = this.answer;
    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  get accepterDisplayName() {
    const username = this.answer.accepter_username;
    const name = this.answer.accepter_name;
    return this.siteSettings.display_name_on_posts && name ? name : username;
  }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
  }

  <template>
    {{! template-lint-disable no-unnecessary-concat }}
    {{#if this.answer}}
      <aside
        class={{concatClass
          "quote accepted-answer d-solved-answer"
          (if this.hasExcerpt "accepted-answer--has-excerpt")
          (unless this.content "title-only")
        }}
        data-expanded="{{this.expanded}}"
        data-username={{this.answer.username}}
        data-post={{this.answer.post_number}}
        data-topic={{this.topic.id}}
      >
        <div class="d-solved-answer__header">
          <h3 class="d-solved-answer__title">
            {{icon "far-square-check"}}
            {{i18n "solved.title"}}
          </h3>
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
            <UserLink @username={{this.answer.username}}>
              {{boundAvatarTemplate this.answer.avatar_template "tiny"}}
            </UserLink>
            <InterpolatedTranslation
              @key="solved.accepted_answer_solver_info"
              as |Placeholder|
            >
              <Placeholder @name="user" @class="d-solved-answer__solver">
                {{this.solverDisplayName}}
              </Placeholder>
              <Placeholder @name="post">
                <a class="d-solved-answer__post-link" href={{this.postPath}}>
                  {{this.postNumber}}
                </a>
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
