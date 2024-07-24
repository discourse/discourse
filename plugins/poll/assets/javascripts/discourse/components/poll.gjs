import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import round from "discourse/lib/round";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import PollBreakdownModal from "../components/modal/poll-breakdown";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";
import PollButtonsDropdown from "../components/poll-buttons-dropdown";
import PollInfo from "../components/poll-info";
import PollOptions from "../components/poll-options";
import PollResultsPie from "../components/poll-results-pie";
import PollResultsTabs from "../components/poll-results-tabs";

const STAFF_ONLY = "staff_only";
const RANKED_CHOICE = "ranked_choice";
const ON_VOTE = "on_vote";
const ON_CLOSE = "on_close";

export default class PollComponent extends Component {
  @service currentUser;
  @service siteSettings;
  @service appEvents;
  @service dialog;
  @service router;
  @service modal;
  @tracked isStaff = this.currentUser && this.currentUser.staff;
  @tracked
  showResults =
    this.args.hasSavedVote ||
    (this.args.topicArchived && !this.args.staffOnly) ||
    (this.args.closed && !this.args.staffOnly);
  isMe = this.currentUser && this.args.post.user_id === this.currentUser.id;

  checkUserGroups = (user, poll) => {
    const pollGroups =
      poll && poll.groups && poll.groups.split(",").map((g) => g.toLowerCase());

    if (!pollGroups) {
      return true;
    }

    const userGroups =
      user && user.groups && user.groups.map((g) => g.name.toLowerCase());

    return userGroups && pollGroups.some((g) => userGroups.includes(g));
  };

  areRanksValid = (arr) => {
    let ranks = new Set(); // Using a Set to keep track of unique ranks
    let hasNonZeroDuplicate = false;

    arr.forEach((obj) => {
      const rank = obj.rank;

      if (rank !== 0) {
        if (ranks.has(rank)) {
          hasNonZeroDuplicate = true;
          return; // Exit forEach loop if a non-zero duplicate is found
        }
        ranks.add(rank);
      }
    });

    return !hasNonZeroDuplicate;
  };

  @action
  async castVotes(option) {
    let success = false;
    if (!this.currentUser) {
      return;
    }
    await this.args.castVotes(option).then(() => {
      success = true;
    });
    if (success) {
      if (this.args.poll.results !== "on_close") {
        this.showResults = true;
      }
      if (this.args.poll.results === "staff_only") {
        if (this.currentUser && this.currentUser.staff) {
          this.showResults = true;
        } else {
          this.showResults = false;
        }
      }
    }
  }

  @action
  async removeVote() {
    let success = false;
    if (!this.currentUser) {
      return;
    }
    await this.args.removeVote().then(() => {
      success = true;
    });
    if (success) {
      this.showResults = false;
    }
  }

  get min() {
    let min = parseInt(this.args.poll.min, 10);
    if (isNaN(min) || min < 0) {
      min = 1;
    }

    return min;
  }

  get max() {
    let max = parseInt(this.args.poll.max, 10);
    const numOptions = this.args.poll.options.length;
    if (isNaN(max) || max > numOptions) {
      max = numOptions;
    }
    return max;
  }

  get hasVoted() {
    return this.args.vote && this.args.vote.length > 0;
  }

  get hideResultsDisabled() {
    return (
      !this.args.staffOnly && (this.args.closed || this.args.topicArchived)
    );
  }

  @action
  toggleResults() {
    const showResults = !this.showResults;
    this.showResults = showResults;
  }

  @action
  toggleOption(option, rank = 0) {
    if (this.args.closed) {
      return;
    }
    if (!this.currentUser) {
      // unlikely, handled by template logic
      return;
    }
    if (!this.checkUserGroups(this.currentUser, this.args.poll)) {
      return;
    }

    if (
      !this.args.isMultiple &&
      !this.args.isRankedChoice &&
      this.args.vote.length === 1 &&
      this.args.vote[0] === option.id
    ) {
      return this.removeVote();
    }

    if (!this.args.isMultiple && !this.args.isRankedChoice) {
      this.args.vote.length = 0;
    }

    this.args.toggleOption(option, rank);

    if (!this.args.isMultiple && !this.args.isRankedChoice) {
      this.castVotes(option);
    }
  }

  get canCastVotes() {
    if (this.args.closed || !this.currentUser) {
      return false;
    }

    const selectedOptionCount = this.args.vote?.length || 0;

    if (this.args.isMultiple) {
      return selectedOptionCount >= this.min && selectedOptionCount <= this.max;
    }

    if (this.args.isRankedChoice) {
      return (
        this.args.options.length === this.args.vote.length &&
        this.areRanksValid(this.args.vote)
      );
    }

    return selectedOptionCount > 0;
  }

  get notInVotingGroup() {
    return !this.checkUserGroups(this.currentUser, this.args.poll);
  }

  get pollGroups() {
    return I18n.t("poll.results.groups.title", {
      groups: this.args.poll.groups,
    });
  }

  get showCastVotesButton() {
    return (
      (this.args.isMultiple || this.args.isRankedChoice) && !this.showResults
    );
  }

  get castVotesButtonClass() {
    return `btn cast-votes ${
      this.canCastVotes ? "btn-primary" : "btn-default"
    }`;
  }

  get castVotesButtonIcon() {
    return !this.castVotesDisabled ? "check" : "far-square";
  }

  get castVotesDisabled() {
    return !this.canCastVotes;
  }

  get showHideResultsButton() {
    return this.showResults && !this.hideResultsDisabled;
  }

  get showShowResultsButton() {
    return (
      !this.showResults &&
      !this.hideResultsDisabled &&
      !(
        this.args.poll.results === ON_VOTE &&
        !this.args.hasSavedVote &&
        !this.isMe
      ) &&
      !(this.args.poll.results === ON_CLOSE && !this.args.closed) &&
      !(this.args.poll.results === STAFF_ONLY && !this.args.isStaff) &&
      this.args.voters > 0
    );
  }

  get showRemoveVoteButton() {
    return (
      this.showResults &&
      !this.args.closed &&
      !this.hideResultsDisabled &&
      this.args.hasSavedVote
    );
  }

  get isCheckbox() {
    if (this.args.isMultiple) {
      return true;
    } else {
      return false;
    }
  }

  get resultsWidgetTypeClass() {
    const type = this.args.poll.type;
    return this.args.isNumber || this.args.poll.chart_type !== PIE_CHART_TYPE
      ? `discourse-poll-${type}-results`
      : "discourse-poll-pie-chart";
  }

  get resultsPie() {
    return this.args.poll.chart_type === PIE_CHART_TYPE;
  }

  get averageRating() {
    const totalScore = this.args.options.reduce((total, o) => {
      return total + parseInt(o.html, 10) * parseInt(o.votes, 10);
    }, 0);

    const average =
      this.args.voters === 0 ? 0 : round(totalScore / this.args.voters, -2);

    return htmlSafe(I18n.t("poll.average_rating", { average }));
  }

  @action
  dropDownClick(dropDownAction) {
    this[dropDownAction]();
  }

  @action
  async toggleStatus() {
    let status;
    status = await this.args.toggleStatus();

    if (
      this.state.poll.results === "on_close" ||
      this.state.poll.results === "always"
    ) {
      this.showResults = status === "closed";
    }
  }

  @action
  showBreakdown() {
    this.modal.show(PollBreakdownModal, {
      model: this.args.attrs,
    });
  }

  @action
  exportResults() {
    const queryID =
      this.args.poll.type === RANKED_CHOICE
        ? this.siteSettings.poll_export_ranked_choice_data_explorer_query_id
        : this.siteSettings.poll_export_data_explorer_query_id;

    // This uses the Data Explorer plugin export as CSV route
    // There is detection to check if the plugin is enabled before showing the button
    ajax(`/admin/plugins/explorer/queries/${queryID}/run.csv`, {
      type: "POST",
      data: {
        // needed for data-explorer route compatibility
        params: JSON.stringify({
          poll_name: this.args.poll.name,
          post_id: this.args.post.id.toString(), // needed for data-explorer route compatibility
        }),
        explain: false,
        limit: 1000000,
        download: 1,
      },
    })
      .then((csvContent) => {
        const downloadLink = document.createElement("a");
        const blob = new Blob([csvContent], {
          type: "text/csv;charset=utf-8;",
        });
        downloadLink.href = URL.createObjectURL(blob);
        downloadLink.setAttribute(
          "download",
          `poll-export-${this.args.poll.name}-${this.args.post.id}.csv`
        );
        downloadLink.click();
        downloadLink.remove();
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_exporting_results"));
        }
      });
  }

  <template>
    <div class="poll-container">
      {{htmlSafe @titleHTML}}
      {{#if this.notInVotingGroup}}
        <div class="alert alert-danger">{{this.pollGroups}}</div>
      {{/if}}
      {{#if this.showResults}}
        <div class={{this.resultsWidgetTypeClass}}>
          {{#if @isNumber}}
            <span>{{this.averageRating}}</span>
          {{else}}
            {{#if this.resultsPie}}
              <PollResultsPie @id={{this.id}} @options={{@options}} />
            {{else}}
              <PollResultsTabs
                @options={{@options}}
                @pollName={{@poll.name}}
                @pollType={{@poll.type}}
                @isRankedChoice={{@isRankedChoice}}
                @isPublic={{@poll.public}}
                @postId={{@post.id}}
                @vote={{@vote}}
                @voters={{@preloadedVoters}}
                @votersCount={{@poll.voters}}
                @fetchVoters={{@fetchVoters}}
                @rankedChoiceOutcome={{@rankedChoiceOutcome}}
              />
            {{/if}}
          {{/if}}
        </div>
      {{else}}
        <PollOptions
          @isCheckbox={{this.isCheckbox}}
          @isRankedChoice={{@isRankedChoice}}
          @rankedChoiceDropdownContent={{@rankedChoiceDropdownContent}}
          @options={{@options}}
          @votes={{@vote}}
          @sendOptionSelect={{this.toggleOption}}
        />
      {{/if}}
    </div>
    <PollInfo
      @options={{@options}}
      @min={{this.min}}
      @max={{this.max}}
      @isMultiple={{@isMultiple}}
      @close={{@close}}
      @closed={{@closed}}
      @results={{@poll.results}}
      @showResults={{this.showResults}}
      @postUserId={{@poll.post.user_id}}
      @isPublic={{@poll.public}}
      @hasVoted={{this.hasVoted}}
      @voters={{@voters}}
    />
    <div class="poll-buttons">
      {{#if this.showCastVotesButton}}
        <DButton
          @class={{this.castVotesButtonClass}}
          @title="poll.cast-votes.title"
          @disabled={{this.castVotesDisabled}}
          @action={{this.castVotes}}
        >
          {{icon this.castVotesButtonIcon}}
          <span class="d-button-label">{{i18n "poll.cast-votes.label"}}</span>
        </DButton>
      {{/if}}

      {{#if this.showHideResultsButton}}
        <DButton
          class="btn btn-default toggle-results"
          title="poll.hide-results.title"
          @action={{this.toggleResults}}
        >
          {{icon "chevron-left"}}
          <span class="d-button-label">{{i18n "poll.hide-results.label"}}</span>
        </DButton>
      {{/if}}

      {{#if this.showShowResultsButton}}
        <DButton
          @class="btn btn-default toggle-results"
          @title="poll.show-results.title"
          @action={{this.toggleResults}}
        >
          {{icon "chart-bar"}}
          <span class="d-button-label">{{i18n "poll.show-results.label"}}</span>
        </DButton>
      {{/if}}

      {{#if this.showRemoveVoteButton}}
        <DButton
          @class="btn btn-default remove-vote"
          @title="poll.remove-vote.title"
          @action={{this.removeVote}}
        >
          {{icon "undo"}}
          <span class="d-button-label">{{i18n "poll.remove-vote.label"}}</span>
        </DButton>
      {{/if}}

      <PollButtonsDropdown
        @closed={{@closed}}
        @voters={{@voters}}
        @isStaff={{@isStaff}}
        @isMe={{this.isMe}}
        @isRankedChoice={{@isRankedChoice}}
        @topicArchived={{@topicArchived}}
        @groupableUserFields={{@groupableUserFields}}
        @isAutomaticallyClosed={{@isAutomaticallyClosed}}
        @dropDownClick={{this.dropDownClick}}
      />
    </div>
  </template>
}
