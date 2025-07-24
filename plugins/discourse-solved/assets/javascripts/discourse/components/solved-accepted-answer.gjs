import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PostQuotedContent from "discourse/components/post/quoted-content";
import concatClass from "discourse/helpers/concat-class";
import { iconHTML } from "discourse/lib/icon-library";
import { formatUsername } from "discourse/lib/utilities";
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

  get htmlAccepter() {
    if (!this.siteSettings.show_who_marked_solved) {
      return;
    }

    const { accepter_username, accepter_name } = this.acceptedAnswer;
    const displayName = this.#getDisplayName(accepter_username, accepter_name);

    if (!displayName) {
      return;
    }

    return htmlSafe(
      i18n("solved.marked_solved_by", {
        username: displayName,
        username_lower: accepter_username.toLowerCase(),
      })
    );
  }

  get htmlSolvedBy() {
    const { username, name, post_number: postNumber } = this.acceptedAnswer;
    if (!username || !postNumber) {
      return;
    }

    const displayedUser = this.#getDisplayName(username, name);
    const data = {
      icon: iconHTML("square-check", { class: "accepted" }),
      username_lower: username.toLowerCase(),
      username: displayedUser,
      post_path: `${this.topic.url}/${postNumber}`,
      post_number: postNumber,
      user_path: this.store.createRecord("user", { username }).path,
    };

    return htmlSafe(i18n("solved.accepted_html", data));
  }

  #getDisplayName(username, name) {
    if (!username) {
      return null;
    }

    return this.siteSettings.display_name_on_posts && name
      ? name
      : formatUsername(username);
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
              {{this.htmlSolvedBy}}
            </div>
            <div class="accepted-answer--accepter">
              {{this.htmlAccepter}}
            </div>
          </div>
        </:title>
      </PostQuotedContent>
    {{/if}}
  </template>
}
