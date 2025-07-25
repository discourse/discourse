import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import PostVotingCommentComposer from "./post-voting-comment-composer";

export default class PostVotingCommentEditor extends Component {
  @service siteSettings;

  @tracked value = this.args.raw;
  @tracked submitDisabled = true;

  @action
  updateValue(value) {
    this.value = value;
    this.submitDisabled =
      value.length < this.siteSettings.min_post_length ||
      value.length > this.siteSettings.post_voting_comment_max_raw_length;
  }

  @action
  onKeyDown(e) {
    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      this.saveComment();
    }
  }

  @action
  saveComment() {
    this.submitDisabled = true;

    const data = {
      comment_id: this.args.id,
      raw: this.value,
    };

    return ajax("/post_voting/comments", {
      type: "PUT",
      data,
    })
      .then(this.args.onSave)
      .catch(popupAjaxError)
      .finally(() => {
        this.submitDisabled = false;
      });
  }

  <template>
    <div class="post-voting-comment-editor post-voting-comment-editor-{{@id}}">
      <PostVotingCommentComposer
        @onInput={{this.updateValue}}
        @raw={{@raw}}
        @onKeyDown={{this.onKeyDown}}
      />

      <DButton
        @action={{this.saveComment}}
        @disabled={{this.submitDisabled}}
        @label="post_voting.post.post_voting_comment.edit"
        @icon="pencil"
        class="btn-primary post-voting-comment-editor-submit"
      />

      <DButton
        @display="link"
        @action={{@onCancel}}
        @label="post_voting.post.post_voting_comment.cancel"
        class="post-voting-comment-editor-cancel"
      />
    </div>
  </template>
}
