import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
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
import PollResultsStandard from "../components/poll-results-standard";

const FETCH_VOTERS_COUNT = 25;
const STAFF_ONLY = "staff_only";
const MULTIPLE = "multiple";
const NUMBER = "number";
const REGULAR = "regular";
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
  @tracked vote = this.args.attrs.vote || [];
  @tracked titleHTML = htmlSafe(this.args.attrs.titleHTML);
  @tracked topicArchived = this.args.attrs.post.get("topic.archived");
  @tracked options = [];
  @tracked poll = this.args.attrs.poll;
  @tracked voters = this.poll.voters || 0;
  @tracked preloadedVoters = this.args.preloadedVoters || [];
  @tracked staffOnly = this.poll.results === STAFF_ONLY;
  @tracked isMultiple = this.poll.type === MULTIPLE;
  @tracked isNumber = this.poll.type === NUMBER;
  @tracked showingResults = false;
  @tracked hasSavedVote = this.args.attrs.hasSavedVote;
  @tracked status = this.poll.status;
  @tracked
  showResults =
    this.hasSavedVote ||
    this.showingResults ||
    (this.topicArchived && !this.staffOnly) ||
    (this.closed && !this.staffOnly);
  post = this.args.attrs.post;
  isMe =
    this.currentUser && this.args.attrs.post.user_id === this.currentUser.id;

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
  castVotes = (option) => {
    if (!this.canCastVotes) {
      return;
    }
    if (!this.currentUser) {
      return;
    }

    return ajax("/polls/vote", {
      type: "PUT",
      data: {
        post_id: this.args.attrs.post.id,
        poll_name: this.poll.name,
        options: this.vote,
      },
    })
      .then(({ poll }) => {
        this.options = [...poll.options];
        this.hasSavedVote = true;
        this.poll.setProperties(poll);
        this.appEvents.trigger(
          "poll:voted",
          poll,
          this.args.attrs.post,
          this.args.attrs.vote
        );

        const voters = poll.voters;
        this.voters = [Number(voters)][0];

        if (this.poll.results !== "on_close") {
          this.showResults = true;
        }
        if (this.poll.results === "staff_only") {
          if (this.currentUser && this.currentUser.staff) {
            this.showResults = true;
          } else {
            this.showResults = false;
          }
        }
      })
      .catch((error) => {
        if (error) {
          if (!this.isMultiple) {
            this._toggleOption(option);
          }
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_casting_votes"));
        }
      });
  };
  _toggleOption = (option) => {
    let options = this.options;
    let vote = this.vote;

    if (this.isMultiple) {
      const chosenIdx = vote.indexOf(option.id);

      if (chosenIdx !== -1) {
        vote.splice(chosenIdx, 1);
      } else {
        vote.push(option.id);
      }
    } else {
      vote = [option.id];
    }

    this.vote = [...vote];
    this.options = [...options];
  };
  constructor() {
    super(...arguments);
    this.id = this.args.attrs.id;
    this.post = this.args.attrs.post;
    this.options = this.poll.options;
    this.groupableUserFields = this.args.attrs.groupableUserFields;
  }

  get min() {
    let min = parseInt(this.args.attrs.poll.min, 10);
    if (isNaN(min) || min < 0) {
      min = 1;
    }

    return min;
  }

  get max() {
    let max = parseInt(this.args.attrs.poll.max, 10);
    const numOptions = this.args.attrs.poll.options.length;
    if (isNaN(max) || max > numOptions) {
      max = numOptions;
    }
    return max;
  }

  get closed() {
    return this.status === "closed" || this.isAutomaticallyClosed;
  }

  get isAutomaticallyClosed() {
    const poll = this.poll;
    return (
      (poll.close ?? false) &&
      moment.utc(poll.close, "YYYY-MM-DD HH:mm:ss Z") <= moment()
    );
  }

  get hasVoted() {
    return this.vote && this.vote.length > 0;
  }

  get hideResultsDisabled() {
    return !this.staffOnly && (this.closed || this.topicArchived);
  }

  @action
  toggleOption(option) {
    if (this.closed) {
      return;
    }
    if (!this.currentUser) {
      // unlikely, handled by template logic
      return;
    }
    if (!this.checkUserGroups(this.currentUser, this.poll)) {
      return;
    }

    if (
      !this.isMultiple &&
      this.vote.length === 1 &&
      this.vote[0] === option.id
    ) {
      return this.removeVote();
    }

    if (!this.isMultiple) {
      this.vote.length = 0;
    }

    this._toggleOption(option);

    if (!this.isMultiple) {
      this.castVotes(option);
    }
  }

  @action
  toggleResults() {
    const showResults = !this.showResults;
    this.showResults = showResults;
  }

  get canCastVotes() {
    if (this.closed || this.showingResults || !this.currentUser) {
      return false;
    }

    const selectedOptionCount = this.vote?.length || 0;

    if (this.isMultiple) {
      return selectedOptionCount >= this.min && selectedOptionCount <= this.max;
    }

    return selectedOptionCount > 0;
  }

  get notInVotingGroup() {
    return !this.checkUserGroups(this.currentUser, this.poll);
  }

  get pollGroups() {
    return I18n.t("poll.results.groups.title", { groups: this.poll.groups });
  }

  get showCastVotesButton() {
    return this.isMultiple && !this.showResults;
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
      !(this.poll.results === ON_VOTE && !this.hasSavedVote && !this.isMe) &&
      !(this.poll.results === ON_CLOSE && !this.closed) &&
      !(this.poll.results === STAFF_ONLY && !this.isStaff) &&
      this.voters > 0
    );
  }

  get showRemoveVoteButton() {
    return (
      !this.showResults &&
      !this.closed &&
      !this.hideResultsDisabled &&
      this.hasSavedVote
    );
  }

  get isCheckbox() {
    if (this.isMultiple) {
      return true;
    } else {
      return false;
    }
  }

  get resultsWidgetTypeClass() {
    const type = this.poll.type;
    return this.isNumber || this.poll.chart_type !== PIE_CHART_TYPE
      ? `discourse-poll-${type}-results`
      : "discourse-poll-pie-chart";
  }

  get resultsPie() {
    return this.poll.chart_type === PIE_CHART_TYPE;
  }

  get averageRating() {
    const totalScore = this.options.reduce((total, o) => {
      return total + parseInt(o.html, 10) * parseInt(o.votes, 10);
    }, 0);

    const average = this.voters === 0 ? 0 : round(totalScore / this.voters, -2);

    return htmlSafe(I18n.t("poll.average_rating", { average }));
  }

  @action
  updatedVoters() {
    this.preloadedVoters = this.args.preloadedVoters;
    this.options = [...this.args.options];
  }

  @action
  fetchVoters(optionId) {
    let votersCount;
    this.loading = true;
    let options = this.options;
    options.find((option) => option.id === optionId).loading = true;
    this.options = [...options];

    votersCount = this.options.find((option) => option.id === optionId).votes;

    return ajax("/polls/voters.json", {
      data: {
        post_id: this.post.id,
        poll_name: this.poll.name,
        option_id: optionId,
        page: Math.floor(votersCount / FETCH_VOTERS_COUNT) + 1,
        limit: FETCH_VOTERS_COUNT,
      },
    })
      .then((result) => {
        const voters = optionId
          ? this.preloadedVoters[optionId]
          : this.preloadedVoters;
        const newVoters = optionId ? result.voters[optionId] : result.voters;
        const votersSet = new Set(voters.map((voter) => voter.username));
        newVoters.forEach((voter) => {
          if (!votersSet.has(voter.username)) {
            votersSet.add(voter.username);
            voters.push(voter);
          }
        });
        // remove users who changed their vote
        if (this.poll.type === REGULAR) {
          Object.keys(this.preloadedVoters).forEach((otherOptionId) => {
            if (optionId !== otherOptionId) {
              this.preloadedVoters[otherOptionId] = this.preloadedVoters[
                otherOptionId
              ].filter((voter) => !votersSet.has(voter.username));
            }
          });
        }
        this.preloadedVoters[optionId] = [
          ...new Set([...this.preloadedVoters[optionId], ...newVoters]),
        ];
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_fetching_voters"));
        }
      })
      .finally(() => {
        options.find((option) => option.id === optionId).loading = false;
        this.options = [...options];
      });
  }

  @action
  dropDownClick(dropDownAction) {
    this[dropDownAction]();
  }

  @action
  removeVote() {
    return ajax("/polls/vote", {
      type: "DELETE",
      data: {
        post_id: this.post.id,
        poll_name: this.poll.name,
      },
    })
      .then(({ poll }) => {
        this.options = [...poll.options];
        this.poll.setProperties(poll);
        this.vote = [];
        this.voters = poll.voters;
        this.hasSavedVote = false;
        this.appEvents.trigger("poll:voted", poll, this.post, this.vote);
      })
      .catch((error) => popupAjaxError(error));
  }

  @action
  toggleStatus() {
    if (this.isAutomaticallyClosed) {
      return;
    }

    this.dialog.yesNoConfirm({
      message: I18n.t(this.closed ? "poll.open.confirm" : "poll.close.confirm"),
      didConfirm: () => {
        const status = this.closed ? "open" : "closed";
        ajax("/polls/toggle_status", {
          type: "PUT",
          data: {
            post_id: this.post.id,
            poll_name: this.poll.name,
            status,
          },
        })
          .then(() => {
            this.poll.status = status;
            this.status = status;
            if (
              this.poll.results === "on_close" ||
              this.poll.results === "always"
            ) {
              this.showResults = this.status === "closed";
            }
          })
          .catch((error) => {
            if (error) {
              popupAjaxError(error);
            } else {
              this.dialog.alert(I18n.t("poll.error_while_toggling_status"));
            }
          });
      },
    });
  }

  @action
  showBreakdown() {
    this.modal.show(PollBreakdownModal, {
      model: this.args.attrs,
    });
  }

  @action
  exportResults() {
    const queryID = this.siteSettings.poll_export_data_explorer_query_id;

    // This uses the Data Explorer plugin export as CSV route
    // There is detection to check if the plugin is enabled before showing the button
    ajax(`/admin/plugins/explorer/queries/${queryID}/run.csv`, {
      type: "POST",
      data: {
        // needed for data-explorer route compatibility
        params: JSON.stringify({
          poll_name: this.poll.name,
          post_id: this.post.id.toString(), // needed for data-explorer route compatibility
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
          `poll-export-${this.poll.name}-${this.post.id}.csv`
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
    <div
      {{didUpdate this.updatedVoters @preloadedVoters}}
      class="poll-container"
    >
      {{this.titleHTML}}
      {{#if this.notInVotingGroup}}
        <div class="alert alert-danger">{{this.pollGroups}}</div>
      {{/if}}
      {{#if this.showResults}}
        <div class={{this.resultsWidgetTypeClass}}>
          {{#if this.isNumber}}
            <span>{{this.averageRating}}</span>
          {{else}}
            {{#if this.resultsPie}}
              <PollResultsPie @id={{this.id}} @options={{this.options}} />
            {{else}}
              <PollResultsStandard
                @options={{this.options}}
                @pollName={{this.poll.name}}
                @pollType={{this.poll.type}}
                @isPublic={{this.poll.public}}
                @postId={{this.post.id}}
                @vote={{this.vote}}
                @voters={{this.preloadedVoters}}
                @votersCount={{this.poll.voters}}
                @fetchVoters={{this.fetchVoters}}
              />
            {{/if}}
          {{/if}}
        </div>
      {{else}}
        <PollOptions
          @isCheckbox={{this.isCheckbox}}
          @options={{this.options}}
          @votes={{this.vote}}
          @sendOptionSelect={{this.toggleOption}}
        />
      {{/if}}
    </div>
    <PollInfo
      @options={{this.options}}
      @min={{this.min}}
      @max={{this.max}}
      @isMultiple={{this.isMultiple}}
      @close={{this.close}}
      @closed={{this.closed}}
      @results={{this.poll.results}}
      @showResults={{this.showResults}}
      @postUserId={{this.poll.post.user_id}}
      @isPublic={{this.poll.public}}
      @hasVoted={{this.hasVoted}}
      @voters={{this.voters}}
    />
    <div class="poll-buttons">
      {{#if this.showCastVotesButton}}
        <button
          class={{this.castVotesButtonClass}}
          title="poll.cast-votes.title"
          disabled={{this.castVotesDisabled}}
          {{on "click" this.castVotes}}
        >
          {{icon this.castVotesButtonIcon}}
          <span class="d-button-label">{{i18n "poll.cast-votes.label"}}</span>
        </button>
      {{/if}}

      {{#if this.showHideResultsButton}}
        <button
          class="btn btn-default toggle-results"
          title="poll.hide-results.title"
          {{on "click" this.toggleResults}}
        >
          {{icon "chevron-left"}}
          <span class="d-button-label">{{i18n "poll.hide-results.label"}}</span>
        </button>
      {{/if}}

      {{#if this.showShowResultsButton}}
        <button
          class="btn btn-default toggle-results"
          title="poll.show-results.title"
          {{on "click" this.toggleResults}}
        >
          {{icon "chart-bar"}}
          <span class="d-button-label">{{i18n "poll.show-results.label"}}</span>
        </button>
      {{/if}}

      {{#if this.showRemoveVoteButton}}
        <button
          class="btn btn-default remove-vote"
          title="poll.remove-vote.title"
          {{on "click" this.removeVote}}
        >
          {{icon "undo"}}
          <span class="d-button-label">{{i18n "poll.remove-vote.label"}}</span>
        </button>
      {{/if}}

      <PollButtonsDropdown
        @closed={{this.closed}}
        @voters={{this.voters}}
        @isStaff={{this.isStaff}}
        @isMe={{this.isMe}}
        @topicArchived={{this.topicArchived}}
        @groupableUserFields={{this.groupableUserFields}}
        @isAutomaticallyClosed={{this.isAutomaticallyClosed}}
        @dropDownClick={{this.dropDownClick}}
      />
    </div>
  </template>
}
