import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import closeOnClickOutside from "discourse/modifiers/close-on-click-outside";
import { i18n } from "discourse-i18n";
import VoteButton from "./vote-button";
import VoteCount from "./vote-count";
import VoteOptions from "./vote-options";

export default class VoteBox extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked votesAlert;
  @tracked allowClick = true;
  @tracked initialVote = false;
  @tracked showOptions = false;

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
        if (result.alert) {
          this.votesAlert = result.votes_left;
        }
        this.allowClick = true;
        this.showOptions = false;
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
        this.showOptions = false;
      })
      .catch(popupAjaxError);
  }

  @action
  showVoteOptions() {
    this.showOptions = true;
  }

  @action
  closeVoteOptions() {
    this.showOptions = false;
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
      />

      {{#if this.showOptions}}
        <VoteOptions
          @topic={{@topic}}
          @removeVote={{this.removeVote}}
          {{closeOnClickOutside this.closeVoteOptions (hash)}}
        />
      {{/if}}

      {{#if this.votesAlert}}
        <div
          class="voting-popup-menu vote-options popup-menu"
          {{closeOnClickOutside this.closeVotesAlert (hash)}}
        >
          {{htmlSafe
            (i18n
              "topic_voting.votes_left"
              count=this.votesAlert
              path="/my/activity/votes"
            )
          }}
        </div>
      {{/if}}
    </div>
  </template>
}
