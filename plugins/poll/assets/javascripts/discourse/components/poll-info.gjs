import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { relativeAge } from "discourse/lib/formatter";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ON_VOTE = "on_vote";
const ON_CLOSE = "on_close";
const STAFF_ONLY = "staff_only";

export default class PollInfoComponent extends Component {
  @service currentUser;

  get multipleHelpText() {
    const { min, max, options } = this.args;
    const optionsCount = options.length;

    if (max > 0) {
      if (min === max && min > 1) {
        return trustHTML(i18n("poll.multiple.help.x_options", { count: min }));
      }

      if (min > 1) {
        if (max < optionsCount) {
          return trustHTML(
            i18n("poll.multiple.help.between_min_and_max_options", {
              min,
              max,
            })
          );
        }

        return trustHTML(
          i18n("poll.multiple.help.at_least_min_options", { count: min })
        );
      }

      if (max <= optionsCount) {
        return trustHTML(
          i18n("poll.multiple.help.up_to_max_options", { count: max })
        );
      }
    }
  }

  get votersLabel() {
    return i18n("poll.voters", { count: this.args.voters });
  }

  get showTotalVotes() {
    return this.args.isMultiple && (this.args.showResults || this.args.closed);
  }

  get totalVotes() {
    return this.args.options.reduce((total, o) => {
      return total + parseInt(o.votes, 10);
    }, 0);
  }

  get totalVotesLabel() {
    return i18n("poll.total_votes", { count: this.totalVotes });
  }

  get showAutomaticClose() {
    return (
      this.args.isAutomaticallyClosed ||
      (!!this.args.closesAt && !this.args.closed)
    );
  }

  get automaticCloseLabel() {
    return trustHTML(
      this.args.isAutomaticallyClosed
        ? i18n("poll.automatic_close.age", { age: this.age })
        : i18n("poll.automatic_close.closes_in", { timeLeft: this.timeLeft })
    );
  }

  get showMultipleHelpText() {
    return (
      this.args.isMultiple &&
      !this.args.showResults &&
      !this.args.showingVotedChoices &&
      !this.args.closed
    );
  }

  get closeTitle() {
    return this.args.closesAt?.format("LLL") ?? "";
  }

  get age() {
    return relativeAge(this.args.closesAt.toDate(), { addAgo: true });
  }

  get timeLeft() {
    return moment().to(this.args.closesAt, true);
  }

  get resultsOnVote() {
    return (
      this.args.results === ON_VOTE &&
      !this.args.hasVoted &&
      !(this.currentUser && this.args.postUserId === this.currentUser.id)
    );
  }

  get resultsOnVoteTitle() {
    return trustHTML(i18n("poll.results.vote.title"));
  }

  get resultsOnClose() {
    return this.args.results === ON_CLOSE && !this.args.closed;
  }

  get resultsOnCloseTitle() {
    return trustHTML(i18n("poll.results.closed.title"));
  }

  get resultsStaffOnly() {
    return (
      this.args.results === STAFF_ONLY &&
      !(this.currentUser && this.currentUser.staff)
    );
  }

  get resultsStaffOnlyTitle() {
    return trustHTML(i18n("poll.results.staff.title"));
  }

  get publicTitle() {
    return (
      !this.args.closed &&
      !this.args.showResults &&
      this.args.isPublic &&
      this.args.results !== STAFF_ONLY
    );
  }

  get publicTitleLabel() {
    return trustHTML(i18n("poll.public.title"));
  }

  get showInstructionsSection() {
    return (
      this.args.showingVotedChoices ||
      this.showMultipleHelpText ||
      this.showAutomaticClose ||
      this.args.closedBy ||
      this.resultsOnVote ||
      this.resultsOnClose ||
      this.resultsStaffOnly ||
      this.publicTitle ||
      this.args.isDynamic
    );
  }

  get closedByLabel() {
    return i18n("poll.closed_by", { username: this.args.closedBy.username });
  }

  <template>
    <div class="poll-info">
      <div class="poll-info_counts">
        <div class="poll-info_counts-count">
          <span class="info-number">{{@voters}}</span>
          <span class="info-label">{{this.votersLabel}}</span>
        </div>
        {{#if this.showTotalVotes}}
          <div class="poll-info_counts-count">
            <span class="info-number">{{this.totalVotes}}</span>
            <span class="info-label">{{this.totalVotesLabel}}</span>
          </div>
        {{/if}}
      </div>
      {{#if this.showInstructionsSection}}
        <ul class="poll-info_instructions">
          {{#if @isDynamic}}
            <li class="is-dynamic">
              {{dIcon "shuffle"}}
              <span>{{i18n "poll.dynamic.enabled_hint"}}</span>
            </li>
          {{/if}}
          {{#if @showingVotedChoices}}
            <li class="vote-recorded">
              {{dIcon "check"}}
              <span>{{i18n "poll.vote_recorded"}}</span>
            </li>
          {{/if}}
          {{#if this.showMultipleHelpText}}
            <li class="multiple-help-text">
              {{dIcon "list-ul"}}
              <span>{{this.multipleHelpText}}</span>
            </li>
          {{/if}}
          {{#if this.showAutomaticClose}}
            <li title={{this.closeTitle}}>
              {{dIcon (if @isAutomaticallyClosed "lock" "far-clock")}}
              <span>{{this.automaticCloseLabel}}</span>
            </li>
          {{/if}}
          {{#if @closedBy}}
            <li class="poll-info_closed-by">
              {{dIcon "lock"}}
              <span>{{this.closedByLabel}}</span>
            </li>
          {{/if}}
          {{#if this.resultsOnVote}}
            <li class="results-on-vote">
              {{dIcon "check"}}
              <span>{{this.resultsOnVoteTitle}}</span>
            </li>
          {{/if}}
          {{#if this.resultsOnClose}}
            <li class="results-on-close">
              {{dIcon "lock"}}
              <span>{{this.resultsOnCloseTitle}}</span>
            </li>
          {{/if}}
          {{#if this.resultsStaffOnly}}
            <li class="results-staff-only">
              {{dIcon "shield-halved"}}
              <span>{{this.resultsStaffOnlyTitle}}</span>
            </li>
          {{/if}}
          {{#if this.publicTitle}}
            <li class="is-public">
              {{dIcon "far-eye"}}
              <span>{{this.publicTitleLabel}}</span>
            </li>
          {{/if}}
        </ul>
      {{/if}}
    </div>
  </template>
}
