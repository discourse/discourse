import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import PostQuotedContent from "discourse/components/post/quoted-content";
import UserLink from "discourse/components/user-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SolvedAcceptedAnswer extends Component {
  @service siteSettings;
  @service store;

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

  get collapsedContent() {
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

  <template>
    {{#if this.acceptedAnswer}}
      <PostQuotedContent
        class={{concatClass
          "accepted-answer"
          (if this.hasExcerpt "accepted-answer--has-excerpt")
          (unless this.collapsedContent "title-only")
        }}
        @collapsedContent={{this.collapsedContent}}
        @decoratorState={{@decoratorState}}
        @id={{this.quoteId}}
        @post={{@post}}
        @quotedPostNumber={{this.acceptedAnswer.post_number}}
        @quotedTopicId={{this.topic.id}}
        @quotedUsername={{this.acceptedAnswer.username}}
      >
        <:title>
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
                <br />
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
        </:title>
      </PostQuotedContent>
    {{/if}}
  </template>
}
