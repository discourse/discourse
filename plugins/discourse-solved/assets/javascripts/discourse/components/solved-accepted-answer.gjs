import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import PostCookedHtml from "discourse/components/post/cooked-html";
import UserLink from "discourse/components/user-link";
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

    return htmlSafe(this.acceptedAnswer.excerpt);
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

  get toggleIcon() {
    return this.expanded ? "chevron-up" : "chevron-down";
  }

  @action
  onClickTitle(event) {
    if (event.target.closest("a") || event.target.closest(".quote-controls")) {
      return;
    }
    this.toggleProperty("expanded");
  }

  <template>
    {{! template-lint-disable no-unnecessary-concat }}
    {{#if this.acceptedAnswer}}
      <aside
        class={{concatClass
          "quote accepted-answer"
          (if this.hasExcerpt "accepted-answer--has-excerpt")
          (unless this.content "title-only")
        }}
        data-expanded="{{this.expanded}}"
        data-username={{this.acceptedAnswer.username}}
        data-post={{this.acceptedAnswer.post_number}}
        data-topic={{this.topic.id}}
      >
        <div
          class="title"
          data-has-quote-controls="true"
          role={{if this.content "button"}}
          {{(if this.content (modifier on "click" this.onClickTitle))}}
        >
          <div class="accepted-answer--solver-accepter">
            <div class="accepted-answer--solver">
              {{#if this.showSolvedBy}}
                {{icon "square-check" class="accepted"}}
                <InterpolatedTranslation
                  @key="solved.accepted_answer_solver_info"
                  as |Placeholder|
                >
                  <Placeholder @name="user">
                    <UserLink
                      @username={{this.solverUsername}}
                    >{{this.solverDisplayName}}</UserLink>
                  </Placeholder>
                  <Placeholder @name="post">
                    <a href={{this.postPath}}>{{this.postNumber}}</a>
                  </Placeholder>
                </InterpolatedTranslation>
              {{/if}}
            </div>
            <div class="accepted-answer--accepter">
              {{#if this.showMarkedBy}}
                <InterpolatedTranslation
                  @key="solved.marked_solved_by"
                  as |Placeholder|
                >
                  <Placeholder @name="user">
                    <UserLink
                      @username={{this.accepterUsername}}
                    >{{this.accepterDisplayName}}</UserLink>
                  </Placeholder>
                </InterpolatedTranslation>
              {{/if}}
            </div>
          </div>
          <div class="quote-controls">
            {{#if this.content}}
              <DButton
                class="btn-flat quote-toggle"
                @action={{fn this.toggleProperty "expanded"}}
                @ariaControls={{this.quoteId}}
                @ariaExpanded={{this.expanded}}
                @ariaLabel={{if this.expanded "post.collapse" "expand"}}
                @title={{if this.expanded "post.collapse" "expand"}}
                @icon={{this.toggleIcon}}
              />
            {{/if}}
            <DButton
              class="btn-flat back"
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
      </aside>
    {{/if}}
  </template>
}
