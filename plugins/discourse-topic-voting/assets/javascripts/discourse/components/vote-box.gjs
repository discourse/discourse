import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import VoteButton from "./vote-button";
import VoteCount from "./vote-count";

export default class VoteBox extends Component {
  @service currentUser;

  #sendVote(url, userVoted) {
    const topic = this.args.topic;

    return ajax(url, {
      type: "POST",
      data: {
        topic_id: topic.id,
      },
    })
      .then((result) => {
        topic.vote_count = result.vote_count;
        topic.user_voted = userVoted;
        this.currentUser.votes_exceeded = !result.can_vote;
        this.currentUser.vote_limit = result.vote_limit;
        this.currentUser.votes_left = result.votes_left;
      })
      .catch(popupAjaxError);
  }

  @action
  addVote() {
    return this.#sendVote("/voting/vote", true);
  }

  @action
  removeVote() {
    return this.#sendVote("/voting/unvote", false);
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
