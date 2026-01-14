import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { castVote, removeVote } from "../lib/post-voting-utilities";
import PostVotingButton from "./post-voting-button";
import PostVotingWhoVotedList from "./post-voting-who-voted-list";

export default class PostVotingVoteControls extends Component {
  @service currentUser;

  @tracked loading;
  @tracked showWhoVoted = false;

  get count() {
    return this.args.post_voting_vote_count || 0;
  }

  get disabled() {
    return this.args.post.topic.archived || this.args.post.topic.closed;
  }

  get hasVotes() {
    return this.args.post.post_voting_has_votes;
  }

  get votedUp() {
    return this.args.post.post_voting_user_voted_direction === "up";
  }

  get votedDown() {
    return this.args.post.post_voting_user_voted_direction === "down";
  }

  @action
  async removeVote(direction) {
    const post = this.args.post;
    const countChange = direction === "up" ? -1 : 1;

    post.post_voting_user_voted_direction = null;
    post.post_voting_vote_count = post.post_voting_vote_count + countChange;

    const voteCount = post.post_voting_vote_count;

    this.loading = true;

    try {
      return await removeVote({ post_id: post.id });
    } catch (error) {
      post.post_voting_user_voted_direction = direction;
      post.post_voting_vote_count = voteCount - countChange;

      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async vote(direction) {
    if (!this.currentUser) {
      return this.args.showLogin();
    }

    const post = this.args.post;

    let vote = {
      post_id: post.id,
      direction,
    };

    const isUpVote = direction === "up";
    let countChange;

    if (post.post_voting_user_voted_direction) {
      countChange = isUpVote ? 2 : -2;
    } else {
      countChange = isUpVote ? 1 : -1;
    }

    post.post_voting_user_voted_direction = direction;
    post.post_voting_vote_count = post.post_voting_vote_count + countChange;

    const voteCount = post.post_voting_vote_count;

    this.loading = true;

    try {
      return await castVote(vote);
    } catch (error) {
      post.setProperties({
        post_voting_user_voted_direction: null,
        post_voting_vote_count: voteCount - countChange,
      });
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  toggleWhoVoted() {
    this.showWhoVoted = !this.showWhoVoted;
  }

  <template>
    <div class="post-voting-post">
      <PostVotingButton
        @direction="up"
        @disabled={{this.disabled}}
        @loading={{this.loading}}
        @removeVote={{this.removeVote}}
        @vote={{this.vote}}
        @voted={{this.votedUp}}
      />

      {{#if this.hasVotes}}
        <DButton
          class="post-voting-post-toggle-voters btn-flat"
          @action={{this.toggleWhoVoted}}
          @translatedLabel={{@post.post_voting_vote_count}}
        />
        {{#if this.showWhoVoted}}
          <PostVotingWhoVotedList
            @post={{@post}}
            @onClickOutside={{this.toggleWhoVoted}}
          />
        {{/if}}
      {{else}}
        <span class="post-voting-post-toggle-voters">
          {{this.count}}
        </span>
      {{/if}}

      <PostVotingButton
        @direction="down"
        @disabled={{this.disabled}}
        @loading={{this.loading}}
        @removeVote={{this.removeVote}}
        @vote={{this.vote}}
        @voted={{this.votedDown}}
      />
    </div>
  </template>
}
