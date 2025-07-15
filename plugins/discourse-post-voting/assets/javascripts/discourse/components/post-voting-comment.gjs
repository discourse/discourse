import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import formatDate from "discourse/helpers/format-date";
import formatUsername from "discourse/helpers/format-username";
import htmlSafe from "discourse/helpers/html-safe";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import PostVotingButton from "./post-voting-button";
import PostVotingCommentActions from "./post-voting-comment-actions";
import PostVotingCommentEditor from "./post-voting-comment-editor";

export function buildAnchorId(commentId) {
  return `post-voting-comment-${commentId}`;
}

export default class PostVotingComment extends Component {
  @service currentUser;

  @tracked isEditing = false;
  @tracked isVoting = false;
  @tracked hidden = false;

  get anchorId() {
    return buildAnchorId(this.args.comment.id);
  }

  @action
  onSave(comment) {
    this.args.updateComment(comment);
    this.collapseEditor();
  }

  @action
  onCancel() {
    this.collapseEditor();
  }

  @action
  removeVote() {
    this.isVoting = true;

    this.args.removeVote(this.args.comment.id);

    return ajax("/post_voting/vote/comment", {
      type: "DELETE",
      data: { comment_id: this.args.comment.id },
    })
      .catch((e) => {
        this.args.vote(this.args.comment.id);
        popupAjaxError(e);
      })
      .finally(() => {
        this.isVoting = false;
      });
  }

  @action
  vote(direction) {
    if (direction !== "up") {
      return;
    }

    this.isVoting = true;

    this.args.vote(this.args.comment.id);

    return ajax("/post_voting/vote/comment", {
      type: "POST",
      data: { comment_id: this.args.comment.id },
    })
      .catch((e) => {
        this.args.removeVote(this.args.comment.id);
        popupAjaxError(e);
      })
      .finally(() => {
        this.isVoting = false;
      });
  }

  @action
  expandEditor() {
    this.isEditing = true;
  }

  @action
  collapseEditor() {
    this.isEditing = false;
  }

  <template>
    <div
      id={{this.anchorId}}
      class="post-voting-comment
        {{if @comment.deleted 'post-voting-comment-deleted'}}"
    >
      {{#if this.isEditing}}
        <PostVotingCommentEditor
          @id={{@comment.id}}
          @raw={{@comment.raw}}
          @onSave={{this.onSave}}
          @onCancel={{this.onCancel}}
        />
      {{else}}
        <div class="post-voting-comment-actions-vote">
          {{#if @comment.post_voting_vote_count}}
            <span
              class="post-voting-comment-actions-vote-count"
            >{{@comment.post_voting_vote_count}}</span>
          {{/if}}

          <PostVotingButton
            @direction="up"
            @loading={{@isVoting}}
            @voted={{@comment.user_voted}}
            @removeVote={{this.removeVote}}
            @vote={{if this.currentUser this.vote (routeAction "showLogin")}}
            @disabled={{@disabled}}
          />
        </div>

        <div class="post-voting-comment-post">
          <span class="post-voting-comment-cooked">{{htmlSafe
              @comment.cooked
            }}</span>

          <span class="post-voting-comment-info-separator">–</span>

          {{#if @comment.username}}
            <a
              class="post-voting-comment-info-username"
              data-user-card={{@comment.username}}
            >
              {{formatUsername @comment.username}}
            </a>
          {{else}}
            <span
              class="post-voting-comment-info-username post-voting-comment-info-username-deleted"
            >
              {{i18n "post_voting.post.post_voting_comment.user.deleted"}}
            </span>
          {{/if}}

          <span class="post-voting-comment-info-created">
            {{formatDate @comment.created_at}}
          </span>

          <PostVotingCommentActions
            @id={{@comment.id}}
            @updateComment={{this.expandEditor}}
            @removeComment={{@removeComment}}
            @comment={{@comment}}
            @disabled={{@disabled}}
          />

        </div>
      {{/if}}
    </div>
  </template>
}
