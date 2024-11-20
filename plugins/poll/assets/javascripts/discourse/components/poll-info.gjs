import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { relativeAge } from "discourse/lib/formatter";
import icon from "discourse-common/helpers/d-icon";
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
        return htmlSafe(i18n("poll.multiple.help.x_options", { count: min }));
      }

      if (min > 1) {
        if (max < optionsCount) {
          return htmlSafe(
            i18n("poll.multiple.help.between_min_and_max_options", {
              min,
              max,
            })
          );
        }

        return htmlSafe(
          i18n("poll.multiple.help.at_least_min_options", { count: min })
        );
      }

      if (max <= optionsCount) {
        return htmlSafe(
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

  get automaticCloseAgeLabel() {
    return i18n("poll.automatic_close.age", this.age);
  }

  get automaticCloseClosesInLabel() {
    return i18n("poll.automatic_close.closes_in", this.timeLeft);
  }

  get showMultipleHelpText() {
    return this.args.isMultiple && !this.args.showResults && !this.args.closed;
  }

  get closeTitle() {
    const closeDate = moment.utc(this.args.close, "YYYY-MM-DD HH:mm:ss Z");
    if (closeDate.isValid()) {
      return closeDate.format("LLL");
    } else {
      return "";
    }
  }

  get age() {
    const closeDate = moment.utc(this.args.close, "YYYY-MM-DD HH:mm:ss Z");
    if (closeDate.isValid()) {
      return relativeAge(closeDate.toDate(), { addAgo: true });
    } else {
      return 0;
    }
  }

  get timeLeft() {
    const closeDate = moment.utc(this.args.close, "YYYY-MM-DD HH:mm:ss Z");
    if (closeDate.isValid()) {
      return moment().to(closeDate, true);
    } else {
      return 0;
    }
  }

  get resultsOnVote() {
    return (
      this.args.results === ON_VOTE &&
      !this.args.hasVoted &&
      !(this.currentUser && this.args.postUserId === this.currentUser.id)
    );
  }

  get resultsOnVoteTitle() {
    return htmlSafe(i18n("poll.results.vote.title"));
  }

  get resultsOnClose() {
    return this.args.results === ON_CLOSE && !this.args.closed;
  }

  get resultsOnCloseTitle() {
    return htmlSafe(i18n("poll.results.closed.title"));
  }

  get resultsStaffOnly() {
    return (
      this.args.results === STAFF_ONLY &&
      !(this.currentUser && this.currentUser.staff)
    );
  }

  get resultsStaffOnlyTitle() {
    return htmlSafe(i18n("poll.results.staff.title"));
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
    return htmlSafe(i18n("poll.public.title"));
  }

  get showInstructionsSection() {
    return (
      this.showMultipleHelpText ||
      this.args.close ||
      this.resultsOnVote ||
      this.resultsOnClose ||
      this.resultsStaffOnly ||
      this.publicTitle
    );
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
          {{#if this.showMultipleHelpText}}
            <li class="multiple-help-text">
              {{icon "list-ul"}}
              <span>{{this.multipleHelpText}}</span>
            </li>
          {{/if}}
          {{#if this.poll.close}}
            {{#if this.isAutomaticallyClosed}}
              <li title={{this.title}}>
                {{icon "lock"}}
                <span>{{this.automaticCloseAgeLabel}}</span>
              </li>
            {{else}}
              <li title={{this.title}}>
                {{icon "far-clock"}}
                <span>{{this.automaticCloseClosesInLabel}}</span>
              </li>
            {{/if}}
          {{/if}}
          {{#if this.resultsOnVote}}
            <li class="results-on-vote">
              {{icon "check"}}
              <span>{{this.resultsOnVoteTitle}}</span>
            </li>
          {{/if}}
          {{#if this.resultsOnClose}}
            <li class="results-on-close">
              {{icon "lock"}}
              <span>{{this.resultsOnCloseTitle}}</span>
            </li>
          {{/if}}
          {{#if this.resultsStaffOnly}}
            <li class="results-staff-only">
              {{icon "shield-halved"}}
              <span>{{this.resultsStaffOnlyTitle}}</span>
            </li>
          {{/if}}
          {{#if this.publicTitle}}
            <li class="is-public">
              {{icon "far-eye"}}
              <span>{{this.publicTitleLabel}}</span>
            </li>
          {{/if}}
        </ul>
      {{/if}}
    </div>
  </template>
}
