import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class PostVotingCommentComposer extends Component {
  @service siteSettings;

  @tracked value = this.args.raw ?? "";

  @action
  onInput(event) {
    this.value = event.target.value;
    this.args.onInput?.(event.target.value);
  }

  get errorMessage() {
    if (this.value.length < this.siteSettings.min_post_length) {
      return i18n("post_voting.post.post_voting_comment.composer.too_short", {
        count: this.siteSettings.min_post_length,
      });
    }

    if (
      this.value.length > this.siteSettings.post_voting_comment_max_raw_length
    ) {
      return i18n("post_voting.post.post_voting_comment.composer.too_long", {
        count: this.siteSettings.post_voting_comment_max_raw_length,
      });
    }
  }

  get remainingCharacters() {
    return (
      this.siteSettings.post_voting_comment_max_raw_length - this.value.length
    );
  }

  <template>
    <div class="post-voting-comments__composer">
      <textarea
        class="post-voting-comments__composer-textarea"
        value={{this.value}}
        {{on "input" this.onInput}}
        {{on "keydown" @onKeyDown}}
        maxlength={{this.siteSettings.post_voting_comment_max_raw_length}}
      ></textarea>

      {{#if this.value.length}}
        {{#if this.errorMessage}}
          <div class="post-voting-comments__composer-flash has-error">
            {{this.errorMessage}}
          </div>
        {{else}}
          <div class="post-voting-comments__composer-flash">
            {{this.value.length}}/<span
            >{{this.siteSettings.post_voting_comment_max_raw_length}}</span>
          </div>
        {{/if}}
      {{/if}}
    </div>
  </template>
}
