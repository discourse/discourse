import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import round from "discourse/lib/round";
import I18n from "discourse-i18n";
import i18n from "discourse-common/helpers/i18n";
import PollBreakdownModal from "../components/modal/poll-breakdown";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";
import PollResultsPie from "../components/poll-results-pie";
import PollResultsTabs from "../components/poll-results-tabs";
import PollOptions from "../components/poll-options";
import PollInfo from "../components/poll-info";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import dIcon from "discourse-common/helpers/d-icon";

const FETCH_VOTERS_COUNT = 25;

const buttonOptionsMap = {
  exportResults: {
    className: "btn-default export-results",
    label: "poll.export-results.label",
    title: "poll.export-results.title",
    icon: "download",
    action: "exportResults",
  },
  showBreakdown: {
    className: "btn-default show-breakdown",
    label: "poll.breakdown.breakdown",
    icon: "chart-pie",
    action: "showBreakdown",
  },
  openPoll: {
    className: "btn-default toggle-status",
    label: "poll.open.label",
    title: "poll.open.title",
    icon: "unlock-alt",
    action: "toggleStatus",
  },
  closePoll: {
    className: "btn-default toggle-status",
    label: "poll.close.label",
    title: "poll.close.title",
    icon: "lock",
    action: "toggleStatus",
  },
};

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
  @tracked staffOnly = this.poll.results === "staff_only";
  @tracked isIrv = this.poll.type === "irv";
  @tracked irvOutcome = this.poll.irv_outcome || [];
  @tracked isMultiple = this.poll.type === "multiple";
  @tracked isNumber = this.poll.type === "number";
  @tracked isMultiVoteType = this.isIrv || this.isMultiple;
  @tracked showingResults = false;
  @tracked hasSavedVote = this.args.attrs.hasSavedVote;
  @tracked status = this.poll.status;
  @tracked
  showResults =
    this.hasSavedVote ||
    this.showingResults ||
    (this.args.attrs.post.get("topic.archived") && !this.staffOnly) ||
    (this.closed && !this.staffOnly);
  @tracked getDropdownButtonState;
  post = this.args.attrs.post;
  isMe =
    this.currentUser && this.args.attrs.post.user_id === this.currentUser.id;

  isAutomaticallyClosed = () => {
    const poll = this.poll;
    return (
      poll.close && moment.utc(poll.close, "YYYY-MM-DD HH:mm:ss Z") <= moment()
    );
  };

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
        this.irvOutcome = poll.irv_outcome || [];
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
          if (!this.isMultiple && !this.isIrv) {
            this._toggleOption(option);
          }
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_casting_votes"));
        }
      });
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
  _toggleOption = (option, rank = 0) => {
    let options = this.options;
    let vote = this.vote;

    if (this.isMultiple) {
      const chosenIdx = vote.indexOf(option.id);

      if (chosenIdx !== -1) {
        vote.splice(chosenIdx, 1);
      } else {
        vote.push(option.id);
      }
    } else if (this.isIrv) {
      options.forEach((candidate, i) => {
        const chosenIdx = vote.findIndex((object) => {
          return object.digest === candidate.id;
        });

        if (chosenIdx === -1) {
          vote.push({
            digest: candidate.id,
            rank: candidate.id === option ? rank : 0,
          });
        } else {
          if (candidate.id === option) {
            vote[chosenIdx].rank = rank;
            options[i].rank = rank;
          }
        }
      });
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
    this.getDropdownButtonState = false;
    this.irvDropdownContent = [];

    if (this.isIrv) {
      this.irvDropdownContent.push({
        id: 0,
        name: I18n.t("poll.options.irv.abstain"),
      });
    }

    this.options.forEach((option, i) => {
      option.rank = 0;
      if (this.isIrv) {
        this.irvDropdownContent.push({ id: i + 1, name: (i + 1).toString() });
        this.args.attrs.vote.forEach((vote) => {
          if (vote.digest === option.id) {
            option.rank = vote.rank;
          }
        });
      }
    });
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
    return this.status === "closed" || this.isAutomaticallyClosed();
  }

  get hasVoted() {
    return this.vote && this.vote.length > 0;
  }

  get hideResultsDisabled() {
    return !this.staffOnly && (this.closed || this.topicArchived);
  }

  @action
  toggleOption(option, rank = 0) {
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
      !this.isIrv &&
      this.vote.length === 1 &&
      this.vote[0] === option.id
    ) {
      return this.removeVote();
    }

    if (!this.isMultiple && !this.isIrv) {
      this.vote.length = 0;
    }

    this._toggleOption(option, rank);

    if (!this.isMultiple && !this.isIrv) {
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

    if (this.isIrv) {
      return (
        this.options.length === this.vote.length &&
        this.areRanksValid(this.vote)
      );
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
    return (this.isMultiple || this.isIrv) && !this.showResults;
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
      !(this.poll.results === "on_vote" && !this.hasSavedVote && !this.isMe) &&
      !(this.poll.results === "on_close" && !this.closed) &&
      !(this.poll.results === "staff_only" && !this.isStaff) &&
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
    if (this.isIrv) {
      this.options.forEach((candidate) => {
        let specificVote = this.vote.find(
          (vote) => vote.digest === candidate.id
        );
        let rank = specificVote ? specificVote.rank : 0;
        candidate.rank = rank;
      });
    }
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
        if (this.isIrv) {
          this.preloadedVoters[optionId] = [...new Set([...newVoters])];
        } else {
          const votersSet = new Set(voters.map((voter) => voter.username));
          newVoters.forEach((voter) => {
            if (!votersSet.has(voter.username)) {
              votersSet.add(voter.username);
              voters.push(voter);
            }
          });
          // remove users who changed their vote
          if (this.poll.type === "regular") {
            Object.keys(this.preloadedVoters).forEach((otherOptionId) => {
              if (optionId !== otherOptionId) {
                this.preloadedVoters[otherOptionId] = this.preloadedVoters[
                  otherOptionId
                ].filter((voter) => !votersSet.has(voter.username));
              }
            });
          }
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
  toggleDropdownButtonState() {
    this.getDropdownButtonState = !this.getDropdownButtonState;
  }

  get dropDownButtonState() {
    return this.getDropdownButtonState ? "opened" : "closed";
  }

  get showDropdown() {
    return this.getDropdownContent.length > 1;
  }

  get showDropdownAsButton() {
    return this.getDropdownContent.length === 1;
  }

  @action
  dropDownClick(dropDownAction) {
    this.toggleDropdownButtonState();
    this[dropDownAction]();
  }

  get getDropdownContent() {
    const contents = [];
    const isAdmin = this.currentUser && this.currentUser.admin;
    const dataExplorerEnabled = this.siteSettings.data_explorer_enabled;
    const exportQueryID = this.siteSettings.poll_export_data_explorer_query_id;
    const { poll, post } = this.args.attrs;

    const topicArchived = post.get("topic.archived");

    if (this.args.attrs.groupableUserFields.length && poll.voters > 0) {
      const option = { ...buttonOptionsMap.showBreakdown };
      option.id = option.action;
      contents.push(option);
    }

    if (isAdmin && dataExplorerEnabled && poll.voters > 0 && exportQueryID) {
      const option = { ...buttonOptionsMap.exportResults };
      option.id = option.action;
      contents.push(option);
    }

    if (
      this.currentUser &&
      (this.currentUser.id === post.user_id || this.isStaff) &&
      !topicArchived
    ) {
      if (this.closed) {
        if (!this.args.attrs.isAutomaticallyClosed) {
          const option = { ...buttonOptionsMap.openPoll };
          option.id = option.action;
          contents.push(option);
        }
      } else {
        const option = { ...buttonOptionsMap.closePoll };
        option.id = option.action;
        contents.push(option);
      }
    }

    return contents;
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
        if (this.poll.type === "irv") {
          poll.options.forEach((option) => {
            option.rank = 0;
          });
        }
        this.options = [...poll.options];
        this.poll.setProperties(poll);
        this.irvOutcome = poll.irv_outcome || [];
        this.vote = [];
        this.voters = poll.voters;
        this.hasSavedVote = false;
        this.appEvents.trigger("poll:voted", poll, this.post, this.vote);
      })
      .catch((error) => popupAjaxError(error));
  }

  @action
  toggleStatus() {
    if (this.isAutomaticallyClosed()) {
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
    const queryID =
      this.poll.type === "irv"
        ? this.siteSettings.poll_export_data_explorer_query_id_irv
        : this.siteSettings.poll_export_data_explorer_query_id;

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
              <PollResultsTabs
                @options={{this.options}}
                @pollName={{this.poll.name}}
                @pollType={{this.poll.type}}
                @isIrv={{this.isIrv}}
                @isPublic={{this.poll.public}}
                @postId={{this.post.id}}
                @vote={{this.vote}}
                @voters={{this.preloadedVoters}}
                @votersCount={{this.poll.voters}}
                @fetchVoters={{this.fetchVoters}}
                @irvOutcome={{this.irvOutcome}}
              />
            {{/if}}
          {{/if}}
        </div>
      {{else}}
        <PollOptions
          @isCheckbox={{this.isCheckbox}}
          @isIrv={{this.isIrv}}
          @irvDropdownContent={{this.irvDropdownContent}}
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
          {{dIcon this.castVotesButtonIcon}}
          <span class="d-button-label">{{i18n "poll.cast-votes.label"}}</span>
        </button>
      {{/if}}

      {{#if this.showHideResultsButton}}
        <button
          class="btn btn-default toggle-results"
          title="poll.hide-results.title"
          {{on "click" this.toggleResults}}
        >
          {{dIcon "chevron-left"}}
          <span class="d-button-label">{{i18n "poll.hide-results.label"}}</span>
        </button>
      {{/if}}

      {{#if this.showShowResultsButton}}
        <button
          class="btn btn-default toggle-results"
          title="poll.show-results.title"
          {{on "click" this.toggleResults}}
        >
          {{dIcon "chart-bar"}}
          <span class="d-button-label">{{i18n "poll.show-results.label"}}</span>
        </button>
      {{/if}}

      {{#if this.showRemoveVoteButton}}
        <button
          class="btn btn-default remove-vote"
          title="poll.remove-vote.title"
          {{on "click" this.removeVote}}
        >
          {{dIcon "undo"}}
          <span class="d-button-label">{{i18n "poll.remove-vote.label"}}</span>
        </button>
      {{/if}}

      <div class="poll-buttons-dropdown">
        <div class="widget-dropdown {{this.dropDownButtonState}}">
          {{#if this.showDropdown}}
            <button
              class="widget-dropdown-header btn btn-default"
              title="poll.dropdown.title"
              {{on "click" this.toggleDropdownButtonState}}
            >
              {{dIcon "cog"}}
            </button>
          {{/if}}
          <div class="widget-dropdown-body">
            {{#each this.getDropdownContent as |content|}}
              <div class="widget-dropdown-item">
                <button
                  class="widget-button {{content.className}}"
                  title={{content.title}}
                  {{on "click" (fn this.dropDownClick content.action)}}
                >
                  {{dIcon content.icon}}
                  <span>{{i18n content.label}}</span>
                </button>
              </div>
            {{/each}}
          </div>
        </div>
      </div>
    </div>
  </template>
}
