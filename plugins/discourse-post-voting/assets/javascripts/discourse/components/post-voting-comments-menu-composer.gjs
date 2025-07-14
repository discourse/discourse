import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import PostVotingCommentComposer from "./post-voting-comment-composer";

export default class PostVotingCommentsMenuComposer extends Component {
  @service siteSettings;

  @tracked value = "";
  @tracked submitDisabled = true;

  @action
  onKeyDown(e) {
    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      this.saveComment();
    }
  }

  @action
  updateValue(value) {
    this.submitDisabled =
      value.length < this.siteSettings.min_post_length ||
      value.length > this.siteSettings.post_voting_comment_max_raw_length;
    this.value = value;
  }

  @action
  saveComment() {
    this.submitDisabled = true;

    return ajax("/post_voting/comments", {
      type: "POST",
      data: { raw: this.value, post_id: this.args.id },
    })
      .then((response) => {
        this.args.onSave(response);
        this.value = "";
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.submitDisabled = false;
      });
  }

  <template>
    <div class="post-voting-comments-menu-composer">
      <PostVotingCommentComposer
        @onInput={{this.updateValue}}
        @onKeyDown={{this.onKeyDown}}
      />

      <DButton
        @action={{this.saveComment}}
        @disabled={{this.submitDisabled}}
        @icon="reply"
        @label="post_voting.post.post_voting_comment.submit"
        class="btn-primary post-voting-comments-menu-composer-submit"
      />

      <DButton
        @display="link"
        @action={{@onCancel}}
        @label="post_voting.post.post_voting_comment.cancel"
        class="post-voting-comments-menu-composer-cancel"
      />
    </div>
  </template>
}
