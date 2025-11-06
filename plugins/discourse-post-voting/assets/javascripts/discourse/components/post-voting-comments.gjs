import Component from "@glimmer/component";
import { action } from "@ember/object";
import PostVotingComment from "./post-voting-comment";
import PostVotingCommentsMenu from "./post-voting-comments-menu";

export default class PostVotingComments extends Component {
  comments = this.args.post.comments; // post.comments is a tracked array

  get moreCommentCount() {
    return this.args.post.comments_count - this.comments.length;
  }

  get lastCommentId() {
    return this.comments?.at(-1)?.id ?? 0;
  }

  get disabled() {
    return this.args.post.topic.closed || this.args.post.topic.archived;
  }

  @action
  appendComments(comments) {
    this.comments.push(...comments);
  }

  @action
  removeComment(commentId) {
    const indexToRemove = this.comments.findIndex(
      (comment) => comment.id === commentId
    );

    if (indexToRemove !== -1) {
      const comment = { ...this.comments[indexToRemove], deleted: true };

      this.comments.splice(indexToRemove, 1, comment);
      this.args.post.comments_count--;
    }
  }

  @action
  updateComment(comment) {
    const index = this.comments.findIndex(
      (oldComment) => oldComment.id === comment.id
    );
    this.comments.splice(index, 1, comment);
  }

  @action
  vote(commentId) {
    const index = this.comments.findIndex(
      (oldComment) => oldComment.id === commentId
    );
    const comment = this.comments[index];

    const updatedComment = {
      ...comment,
      post_voting_vote_count: comment.post_voting_vote_count + 1,
      user_voted: true,
    };
    this.comments.splice(index, 1, updatedComment);
  }

  @action
  removeVote(commentId) {
    const index = this.comments.findIndex(
      (oldComment) => oldComment.id === commentId
    );
    const comment = this.comments[index];

    const updatedComment = {
      ...comment,
      post_voting_vote_count: comment.post_voting_vote_count - 1,
      user_voted: false,
    };
    this.comments.splice(index, 1, updatedComment);
  }

  <template>
    <div class="post-voting-comments">
      {{#each this.comments as |comment|}}
        <PostVotingComment
          @comment={{comment}}
          @removeComment={{this.removeComment}}
          @updateComment={{this.updateComment}}
          @vote={{this.vote}}
          @removeVote={{this.removeVote}}
          @disabled={{this.disabled}}
        />
      {{/each}}

      {{#if @canCreatePost}}
        <PostVotingCommentsMenu
          @id={{@post.id}}
          @postNumber={{@post.post_number}}
          @moreCommentCount={{this.moreCommentCount}}
          @lastCommentId={{this.lastCommentId}}
          @appendComments={{this.appendComments}}
        />
      {{/if}}
    </div>
  </template>
}
