import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import VoteButton from "./vote-button";
import VoteCount from "./vote-count";

export default class VoteBox extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked votesAlert;
  @tracked allowClick = true;
  @tracked initialVote = false;

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
        this.currentUser.votes_left = result.votes_left;
        this.votesAlert = result.alert;
        this.allowClick = true;
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
        this.currentUser.votes_left = result.votes_left;
        this.allowClick = true;
      })
      .catch(popupAjaxError);
  }

  @action
  closeVotesAlert() {
    this.votesAlert = null;
  }

  <template>
    <div
      class={{concatClass
        "voting-wrapper"
        (if this.siteSettings.topic_voting_show_who_voted "show-pointer")
      }}
    >
      <VoteCount @topic={{@topic}} @showLogin={{routeAction "showLogin"}} />
      <VoteButton
        @topic={{@topic}}
        @allowClick={{this.allowClick}}
        @showVoteOptions={{this.showVoteOptions}}
        @addVote={{this.addVote}}
        @showLogin={{routeAction "showLogin"}}
        @removeVote={{this.removeVote}}
      />

    </div>
  </template>
}
