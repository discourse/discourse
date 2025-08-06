import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import FlagModal from "discourse/components/modal/flag";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import PostVotingFlag from "../lib/post-voting-flag";

export default class PostVotingCommentActions extends Component {
  @service dialog;
  @service modal;
  @service currentUser;
  @service siteSettings;
  @service site;

  comment = this.args.comment;

  hasPermission() {
    return (
      this.comment.user_id === this.currentUser.id ||
      this.currentUser.admin ||
      this.currentUser.moderator
    );
  }

  get canEdit() {
    return this.currentUser && this.hasPermission && !this.args.disabled;
  }

  get canFlag() {
    return (
      this.currentUser &&
      (this.hasPermission || this.currentUser.can_flag_post_voting_comments) &&
      !this.args.disabled
    );
  }

  @action
  deleteConfirm() {
    this.dialog.deleteConfirm({
      message: i18n("post_voting.post.post_voting_comment.delete.confirm"),
      didConfirm: () => {
        const data = { comment_id: this.args.id };

        ajax("/post_voting/comments", {
          type: "DELETE",
          data,
        })
          .then(() => {
            this.args.removeComment(this.args.id);
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  showFlag() {
    this.comment.availableFlags = this.comment.available_flags;
    this.modal.show(FlagModal, {
      model: {
        flagTarget: new PostVotingFlag(),
        flagModel: this.comment,
        setHidden: () => (this.comment.hidden = true),
        site: this.site,
      },
    });
  }

  <template>
    {{#if this.canEdit}}
      <span class="post-voting-comment-actions">
        <DButton
          @display="link"
          class="post-voting-comment-actions-edit-link"
          @action={{@updateComment}}
          @icon="pencil"
        />
        <DButton
          @display="link"
          class="post-voting-comment-actions-delete-link"
          @action={{this.deleteConfirm}}
          @icon="far-trash-can"
        />

        {{#if this.canFlag}}
          <DButton
            @display="link"
            class="post-voting-comment-actions-flag-link"
            @action={{this.showFlag}}
            @icon="flag"
          />
        {{/if}}
      </span>
    {{/if}}
  </template>
}
