import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import VoteButton from "./vote-button";
import VoteCount from "./vote-count";

export default class VoteBox extends Component {
  @service currentUser;

  @action
  addVote() {
    let topic = this.args.topic;
    return ajax("/voting/vote", {
      type: "POST",
      data: {
        topic_id: topic.id,
      },
    })
      .then((result) => {
        topic.vote_count = result.vote_count;
        topic.user_voted = true;
        this.currentUser.votes_exceeded = !result.can_vote;
        this.currentUser.vote_limit = result.vote_limit;
        this.currentUser.votes_left = result.votes_left;
      })
      .catch(popupAjaxError);
  }

  @action
  removeVote() {
    const topic = this.args.topic;

    return ajax("/voting/unvote", {
      type: "POST",
      data: {
        topic_id: topic.id,
      },
    })
      .then((result) => {
        topic.vote_count = result.vote_count;
        topic.user_voted = false;
        this.currentUser.votes_exceeded = !result.can_vote;
        this.currentUser.vote_limit = result.vote_limit;
        this.currentUser.votes_left = result.votes_left;
      })
      .catch(popupAjaxError);
  }

  <template>
    <div class="voting-wrapper">
      <VoteButton
        @topic={{@topic}}
        @addVote={{this.addVote}}
        @removeVote={{this.removeVote}}
      />
      <VoteCount @topic={{@topic}} />
    </div>
  </template>
}
