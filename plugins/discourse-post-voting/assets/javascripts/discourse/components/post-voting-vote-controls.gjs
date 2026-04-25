import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { castVote, removeVote } from "../lib/post-voting-utilities";
import PostVotingButton from "./post-voting-button";
import PostVotingWhoVotedList from "./post-voting-who-voted-list";

export default class PostVotingVoteControls extends Component {
  @service currentUser;

  @tracked loading;

  get count() {
    return this.args.post.post_voting_vote_count || 0;
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
    const countChange = direction === "up" ? -1 : 1;
    return this.#submitVote(null, countChange, () =>
      removeVote({ post_id: this.args.post.id })
    );
  }

  @action
  async vote(direction) {
    if (!this.currentUser) {
      return this.args.showLogin();
    }

    const post = this.args.post;
    let countChange = post.post_voting_user_voted_direction ? 2 : 1;
    if (direction === "down") {
      countChange *= -1;
    }

    return this.#submitVote(direction, countChange, () =>
      castVote({ post_id: post.id, direction })
    );
  }

  async #submitVote(newDirection, countChange, apiCall) {
    const post = this.args.post;
    const originalDirection = post.post_voting_user_voted_direction;
    const originalCount = post.post_voting_vote_count;

    post.post_voting_user_voted_direction = newDirection;
    post.post_voting_vote_count = originalCount + countChange;

    this.loading = true;

    try {
      return await apiCall();
    } catch (error) {
      post.post_voting_user_voted_direction = originalDirection;
      post.post_voting_vote_count = originalCount;
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
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
        <DMenu
          @identifier="post-voting-popup"
          @interactive={{true}}
          @autofocus={{true}}
          @title={{i18n "vote.toggle_voters"}}
          @ariaLabel={{i18n "vote.toggle_voters"}}
          @triggerClass="post-voting-post__toggle-voters btn-transparent"
        >
          <:trigger>
            {{@post.post_voting_vote_count}}
          </:trigger>
          <:content>
            <PostVotingWhoVotedList @post={{@post}} />
          </:content>
        </DMenu>
      {{else}}
        <span class="post-voting-post__toggle-voters">
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
