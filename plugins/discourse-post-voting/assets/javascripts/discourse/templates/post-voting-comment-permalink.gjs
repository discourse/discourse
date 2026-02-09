import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import formatUsername from "discourse/helpers/format-username";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import PostVotingComment from "discourse/plugins/discourse-post-voting/discourse/components/post-voting-comment";
import PostVotingCommentsMenu from "discourse/plugins/discourse-post-voting/discourse/components/post-voting-comments-menu";

export default class PostVotingCommentPermalinkTemplate extends Component {
  @tracked highlightedCommentId = null;

  isHighlighted = (commentId) => {
    return commentId === this.highlightedCommentId;
  };

  constructor() {
    super(...arguments);
    this.comments = new TrackedArray(this.args.controller.comments || []);
    this.highlightedCommentId = this.args.controller.comment?.id;
  }

  get topic() {
    return this.args.controller.topic;
  }

  get post() {
    return this.args.controller.post;
  }

  get comment() {
    return this.args.controller.comment;
  }

  get disabled() {
    return this.topic?.closed || this.topic?.archived;
  }

  get lastCommentId() {
    return this.comments?.at(-1)?.id ?? 0;
  }

  @action
  appendComments(comments) {
    this.comments.push(...comments);
  }

  @action
  removeComment(commentId) {
    const index = this.comments.findIndex((c) => c.id === commentId);
    if (index !== -1) {
      const comment = { ...this.comments[index], deleted: true };
      this.comments.splice(index, 1, comment);
    }
  }

  @action
  updateComment(comment) {
    const index = this.comments.findIndex((c) => c.id === comment.id);
    if (index !== -1) {
      this.comments.splice(index, 1, comment);
    }
  }

  @action
  vote(commentId) {
    const index = this.comments.findIndex((c) => c.id === commentId);
    if (index !== -1) {
      const comment = this.comments[index];
      const updated = {
        ...comment,
        post_voting_vote_count: comment.post_voting_vote_count + 1,
        user_voted: true,
      };
      this.comments.splice(index, 1, updated);
    }
  }

  @action
  removeVote(commentId) {
    const index = this.comments.findIndex((c) => c.id === commentId);
    if (index !== -1) {
      const comment = this.comments[index];
      const updated = {
        ...comment,
        post_voting_vote_count: comment.post_voting_vote_count - 1,
        user_voted: false,
      };
      this.comments.splice(index, 1, updated);
    }
  }

  <template>
    <div class="post-voting-comment-permalink">
      <div class="post-voting-comment-permalink-header">
        <LinkTo
          @route="topic.fromParamsNear"
          @models={{array this.topic.slug this.topic.id this.post.post_number}}
          class="back-link"
        >
          {{i18n "post_voting.comment.permalink.back_to_topic"}}
        </LinkTo>

        <h1 class="topic-title">{{this.topic.title}}</h1>
      </div>

      <div class="post-voting-comment-permalink-post">
        <div class="post-voting-comment-permalink-post-header">
          {{#if this.post.avatar_template}}
            <a
              href={{userPath this.post.username}}
              data-user-card={{this.post.username}}
              class="post-avatar"
            >
              {{avatar
                this.post
                imageSize="large"
                template=this.post.avatar_template
              }}
            </a>
          {{/if}}
          <div class="post-info">
            {{#if this.post.username}}
              <a
                href={{userPath this.post.username}}
                class="username"
                data-user-card={{this.post.username}}
              >
                {{formatUsername this.post.username}}
              </a>
            {{/if}}
            <span class="post-date">{{formatDate this.post.created_at}}</span>
          </div>
        </div>

        <div class="post-voting-comment-permalink-post-content">
          {{htmlSafe this.post.cooked}}
        </div>
      </div>

      <div class="post-voting-comment-permalink-comments">
        <h2 class="comments-header">
          {{i18n
            "post_voting.comment.permalink.comments_count"
            count=this.comments.length
          }}
        </h2>

        {{#each this.comments as |c|}}
          <div
            class="post-voting-comment-permalink-comment-wrapper
              {{if (this.isHighlighted c.id) 'highlighted'}}"
          >
            <PostVotingComment
              @comment={{c}}
              @topic={{this.topic}}
              @removeComment={{this.removeComment}}
              @updateComment={{this.updateComment}}
              @vote={{this.vote}}
              @removeVote={{this.removeVote}}
              @disabled={{this.disabled}}
            />
          </div>
        {{/each}}

        {{#unless this.disabled}}
          <div id="post_{{this.post.post_number}}">
            <PostVotingCommentsMenu
              @id={{this.post.id}}
              @postNumber={{this.post.post_number}}
              @moreCommentCount={{0}}
              @lastCommentId={{this.lastCommentId}}
              @appendComments={{this.appendComments}}
            />
          </div>
        {{/unless}}
      </div>

      <div class="post-voting-comment-permalink-footer">
        <LinkTo
          @route="topic.fromParamsNear"
          @models={{array this.topic.slug this.topic.id this.post.post_number}}
          class="view-full-topic"
        >
          {{i18n "post_voting.comment.permalink.view_full_topic"}}
        </LinkTo>
      </div>
    </div>
  </template>
}
