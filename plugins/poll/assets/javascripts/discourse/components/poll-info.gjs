import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { relativeAge } from "discourse/lib/formatter";
import icon from "discourse-common/helpers/d-icon";
import I18n from "I18n";

export default class PollInfoComponent extends Component {
  @service currentUser;

  get multipleHelpText() {
  const { min, max, options } = this.args;
  const optionsCount = options.length;

    if (max > 0) {
      if (min === max) {
        if (min > 1) {
          return htmlSafe(
            I18n.t("poll.multiple.help.x_options", { count: min })
          );
        }
      } else if (min > 1) {
        if (max < optionsCount) {
          return htmlSafe(
            I18n.t("poll.multiple.help.between_min_and_max_options", {
              min,
              max,
            })
          );
        } else {
          return htmlSafe(
            I18n.t("poll.multiple.help.at_least_min_options", {
              count: min,
            })
          );
        }
      } else if (max <= optionsCount) {
        return htmlSafe(
          I18n.t("poll.multiple.help.up_to_max_options", { count: max })
        );
      }
    }
  }

  get votersLabel() {
    return I18n.t("poll.voters", { count: this.args.voters });
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
    return I18n.t("poll.total_votes", { count: this.totalVotes });
  }

  get automaticCloseAgeLabel() {
    return I18n.t("poll.automatic_close.age", this.age);
  }

  get automaticCloseClosesInLabel() {
    return I18n.t("poll.automatic_close.closes_in", this.timeLeft);
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
      this.args.results === "on_vote" &&
      !this.args.hasVoted &&
      !(this.currentUser && this.args.postUserId === this.currentUser.id)
    );
  }

  get resultsOnClose() {
    return this.args.results === "on_close" && !this.args.closed;
  }

  get resultsStaffOnly() {
    return (
      this.args.results === "staff_only" &&
      !(this.currentUser && this.currentUser.staff)
    );
  }

  get publicTitle() {
    return (
      !this.args.closed &&
      !this.args.showResults &&
      this.args.isPublic &&
      this.args.results !== "staff_only"
    );
  }

  get publicTitleLabel() {
    return htmlSafe(I18n.t("poll.public.title"));
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
            <li>
              {{icon "check"}}
              <span>{{I18n "poll.results.vote.title"}}</span>
            </li>
          {{/if}}
          {{#if this.resultsOnClose}}
            <li>
              {{icon "lock"}}
              <span>{{I18n "poll.results.closed.title"}}</span>
            </li>
          {{/if}}
          {{#if this.resultsStaffOnly}}
            <li>
              {{icon "shield-alt"}}
              <span>{{I18n "poll.results.staff.title"}}</span>
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
