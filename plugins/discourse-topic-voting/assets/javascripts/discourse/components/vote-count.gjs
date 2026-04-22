import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import avatar from "discourse/helpers/bound-avatar-template";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import VoteCountTrigger from "./vote-count-trigger";

export default class VoteCount extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked voters = null;
  @tracked lastVoteCount = null;
  @tracked totalVoters = 0;
  @tracked isLoading = false;

  get showVoterMenu() {
    return this.siteSettings.topic_voting_show_who_voted && this.currentUser;
  }

  get displayCount() {
    const count = this.args.topic.vote_count;
    if (count >= 1000) {
      const thousands = (count / 1000).toFixed(1).replace(/\.0$/, "");
      return i18n("topic_voting.vote_count_thousands", { count: thousands });
    }
    return count;
  }

  get remainingVoters() {
    return Math.max(this.totalVoters - (this.voters?.length || 0), 0);
  }

  get hasOverflowVoters() {
    return this.remainingVoters > 0;
  }

  @bind
  async loadVoters() {
    // Clear cache if vote count changed
    if (
      this.lastVoteCount !== null &&
      this.lastVoteCount !== this.args.topic.vote_count
    ) {
      this.voters = null;
    }

    if (this.voters) {
      return;
    }

    this.lastVoteCount = this.args.topic.vote_count;
    this.isLoading = true;

    try {
      const users = await ajax("/voting/who", {
        type: "GET",
        data: { topic_id: this.args.topic.id },
      });

      this.totalVoters = this.args.topic.vote_count;
      this.voters = users.map((user) => ({
        template: user.avatar_template,
        username: user.username,
        url: getURL("/u/") + user.username.toLowerCase(),
      }));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{#if this.showVoterMenu}}
      <DMenu
        @identifier="vote-count-voters"
        @triggerComponent={{VoteCountTrigger}}
        @onShow={{this.loadVoters}}
        @modalForMobile={{true}}
        @placement="right"
        class={{concatClass
          "voting-wrapper__count"
          (if (eq @topic.vote_count 0) "no-votes")
        }}
      >
        <:trigger>
          <span class="voting-wrapper__count-text">{{this.displayCount}}</span>
        </:trigger>
        <:content>
          {{#if this.isLoading}}
            <div class="voting-voters__loading">
              {{i18n "loading"}}
            </div>
          {{else if (eq @topic.vote_count 0)}}
            <div class="voting-voters__empty">
              {{i18n "topic_voting.no_votes_yet"}}
            </div>
          {{else if this.voters}}
            <div class="voting-voters__list">
              {{#each this.voters as |voter|}}
                <a
                  class="voting-voters__avatar trigger-user-card"
                  data-user-card={{voter.username}}
                  title={{voter.username}}
                >
                  {{avatar voter.template "small"}}
                </a>
              {{/each}}
              {{#if this.hasOverflowVoters}}
                <div class="voting-voters__overflow">
                  {{i18n
                    "topic_voting.and_more_voters"
                    count=this.remainingVoters
                  }}
                </div>
              {{/if}}
            </div>
          {{/if}}
        </:content>
      </DMenu>
    {{else}}
      <div
        class={{concatClass
          "voting-wrapper__count"
          (if (eq @topic.vote_count 0) "no-votes")
        }}
      >
        <div class="voting-wrapper__count-text">
          {{this.displayCount}}
        </div>
      </div>
    {{/if}}
  </template>
}
