import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import AsyncContent from "discourse/components/async-content";
import PostCookedHtml from "discourse/components/post/cooked-html";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { iconHTML } from "discourse/lib/icon-library";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class SolvedAcceptedAnswer extends Component {
  @service siteSettings;
  @service store;

  @tracked expanded = false;

  get acceptedAnswer() {
    return this.topic.accepted_answer;
  }

  get quoteId() {
    return `accepted-answer-${this.topic.id}-${this.acceptedAnswer.post_number}`;
  }

  get topic() {
    return this.args.post.topic;
  }

  get hasExcerpt() {
    return !!this.acceptedAnswer.excerpt;
  }

  get htmlAccepter() {
    const username = this.acceptedAnswer.accepter_username;
    const name = this.acceptedAnswer.accepter_name;

    if (!this.siteSettings.show_who_marked_solved) {
      return;
    }

    const formattedUsername =
      this.siteSettings.display_name_on_posts && name
        ? name
        : formatUsername(username);

    return htmlSafe(
      i18n("solved.marked_solved_by", {
        username: formattedUsername,
        username_lower: username.toLowerCase(),
      })
    );
  }

  get htmlSolvedBy() {
    const username = this.acceptedAnswer.username;
    const name = this.acceptedAnswer.name;
    const postNumber = this.acceptedAnswer.post_number;

    if (!username || !postNumber) {
      return;
    }

    const displayedUser =
      this.siteSettings.display_name_on_posts && name
        ? name
        : formatUsername(username);

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

  @action
  toggleExpandedPost() {
    if (!this.hasExcerpt) {
      return;
    }

    this.expanded = !this.expanded;
  }

  @action
  async loadExpandedAcceptedAnswer(postNumber) {
    const acceptedAnswer = await ajax(
      `/posts/by_number/${this.topic.id}/${postNumber}`
    );

    return this.store.createRecord("post", acceptedAnswer);
  }

  <template>
    <aside
      class="quote accepted-answer"
      data-post={{this.acceptedAnswer.post_number}}
      data-topic={{this.topic.id}}
      data-expanded={{this.expanded}}
    >
      {{! template-lint-disable no-invalid-interactive }}
      <div
        class={{concatClass
          "title"
          (unless this.hasExcerpt "title-only")
          (if this.hasExcerpt "quote__title--can-toggle-content")
        }}
        {{on "click" this.toggleExpandedPost}}
      >
        <div class="accepted-answer--solver-accepter">
          <div class="accepted-answer--solver">
            {{this.htmlSolvedBy}}
          </div>
          <div class="accepted-answer--accepter">
            {{this.htmlAccepter}}
          </div>
        </div>
        {{#if this.hasExcerpt}}
          <div class="quote-controls">
            <button
              aria-controls={{this.quoteId}}
              aria-expanded={{if this.expanded "true" "false"}}
              class="quote-toggle btn-flat"
              type="button"
              aria-label={{if
                this.expanded
                (i18n "post.collapse")
                (i18n "expand")
              }}
              title={{if this.expanded (i18n "post.collapse") (i18n "expand")}}
            >
              {{icon (if this.expanded "chevron-up" "chevron-down")}}
            </button>
          </div>
        {{/if}}
      </div>
      {{#if this.hasExcerpt}}
        <blockquote id={{this.quoteId}}>
          {{#if this.expanded}}
            <AsyncContent
              @asyncData={{this.loadExpandedAcceptedAnswer}}
              @context={{this.acceptedAnswer.post_number}}
            >
              <:content as |expandedAnswer|>
                <div class="expanded-quote" data-post-id={{expandedAnswer.id}}>
                  <PostCookedHtml
                    @post={{expandedAnswer}}
                    @streamElement={{false}}
                  />
                </div>
              </:content>
            </AsyncContent>
          {{else}}
            {{htmlSafe this.acceptedAnswer.excerpt}}
          {{/if}}
        </blockquote>
      {{/if}}
    </aside>
  </template>
}
