import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { deferAnonymousAction } from "discourse/lib/anonymous-action";
import { afterRender } from "discourse/lib/decorators";
import round from "discourse/lib/round";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import pollBounds from "discourse/plugins/poll/lib/poll-bounds";
import PollBreakdownModal from "../components/modal/poll-breakdown";
import {
  MULTIPLE_POLL_TYPE,
  PIE_CHART_TYPE,
  REGULAR_POLL_TYPE,
} from "../components/modal/poll-ui-builder";
import PollButtonsDropdown from "../components/poll-buttons-dropdown";
import PollInfo from "../components/poll-info";
import PollOptions from "../components/poll-options";
import PollResultsPie from "../components/poll-results-pie";
import PollResultsTabs from "../components/poll-results-tabs";
import PollVotedChoices from "../components/poll-voted-choices";

const FETCH_VOTERS_COUNT = 25;
const STAFF_ONLY = "staff_only";
const MULTIPLE = "multiple";
const NUMBER = "number";
const REGULAR = "regular";
const RANKED_CHOICE = "ranked_choice";
const ON_VOTE = "on_vote";
const ON_CLOSE = "on_close";
const CLOSED_STATUS = "closed";
const OPEN_STATUS = "open";

export default class PollComponent extends Component {
  @service currentUser;
  @service siteSettings;
  @service router;
  @service appEvents;
  @service dialog;
  @service modal;

  @tracked preloadedVoters = this.defaultPreloadedVoters();
  @tracked voterListExpanded = false;

  @tracked hasSavedVote = this.rawSavedVote.length > 0;
  @tracked showTally = false;
  @tracked castingVote = false;

  registerPollButtons = (element) => {
    this.pollButtonsElement = element;
  };

  checkUserGroups = (user, poll) => {
    const pollGroups =
      poll && poll.groups && poll.groups.split(",").map((g) => g.toLowerCase());

    if (!pollGroups) {
      return true;
    }

    const userGroups =
      user &&
      user.visibleGroups &&
      user.visibleGroups.map((g) => g.name.toLowerCase());

    return userGroups && pollGroups.some((g) => userGroups.includes(g));
  };
  areRanksValid = (arr) => {
    let ranks = new Set(); // Using a Set to keep track of unique ranks
    let hasNonZeroDuplicate = false;
    let allZeros = true;

    arr.forEach((obj) => {
      const rank = obj.rank;

      if (rank !== 0) {
        allZeros = false; // Set to false if any rank is non-zero
        if (ranks.has(rank)) {
          hasNonZeroDuplicate = true;
          return; // Exit forEach loop if a non-zero duplicate is found
        }
        ranks.add(rank);
      }
    });

    return !hasNonZeroDuplicate && !allZeros;
  };
  @tracked _vote = this.initialVote();

  @tracked _showResults = this.initialShowResults();

  @tracked _isAmendingVote = this.poll.amendingVoteToggle;

  _toggleOption = (option, rank = 0) => {
    if (this.isMultiple) {
      const chosenIdx = this.vote.indexOf(option.id);

      if (chosenIdx !== -1) {
        this.vote.splice(chosenIdx, 1);
      } else {
        this.vote.push(option.id);
      }
    } else if (this.isRankedChoice) {
      this.options.forEach((candidate) => {
        const chosenIdx = this.vote.findIndex(
          (object) => object.digest === candidate.id
        );

        if (chosenIdx === -1) {
          this.vote.push({
            digest: candidate.id,
            rank: candidate.id === option ? rank : 0,
          });
        } else {
          if (candidate.id === option) {
            this.vote[chosenIdx].rank = rank;
          }
        }
      });
    } else {
      this.vote = [option.id];
    }

    this.vote = [...this.vote];
  };

  get resultsRevealedByClose() {
    return (
      this.poll.results === ON_CLOSE &&
      this.closed &&
      this.poll.options.every((option) => option.votes !== undefined)
    );
  }

  get showResults() {
    return this._showResults || this.resultsRevealedByClose;
  }

  set showResults(value) {
    this._showResults = value;
    this.poll.showResultsToggle = value;
  }

  get resultsVisibilityAllowed() {
    return (
      !(this.poll.results === ON_CLOSE && !this.closed) &&
      !(this.staffOnly && !this.isStaff)
    );
  }

  get isAmendingVote() {
    return this._isAmendingVote;
  }

  set isAmendingVote(value) {
    this._isAmendingVote = value;
    this.poll.amendingVoteToggle = value;
  }

  get hasHiddenSavedVote() {
    return (
      this.hasSavedVote && !this.showResults && !this.resultsVisibilityAllowed
    );
  }

  get showVotedChoices() {
    return this.hasHiddenSavedVote && !this.isAmendingVote;
  }

  get votedChoices() {
    return this.hasSavedVote ? this.rawSavedVote : [];
  }

  get resultsToggleAllowed() {
    return !this.hideResultsDisabled && this.resultsVisibilityAllowed;
  }

  initialShowResults() {
    if (
      this.poll.showResultsToggle !== undefined &&
      this.resultsToggleAllowed
    ) {
      return this.poll.showResultsToggle;
    }

    return (
      this.resultsVisibilityAllowed &&
      (this.hasSavedVote || this.hideResultsDisabled)
    );
  }

  get vote() {
    return this._vote;
  }

  set vote(value) {
    this._vote = value;
    this.poll.inProgressVote = value;
  }

  initialVote() {
    if (this.poll.inProgressVote !== undefined) {
      return this.copyVote(this.poll.inProgressVote);
    }

    return this.savedVote;
  }

  get rawSavedVote() {
    return this.args.post.polls_votes?.[this.poll.name] || [];
  }

  get savedVote() {
    return this.copyVote(this.rawSavedVote);
  }

  copyVote(votes) {
    return this.isRankedChoice
      ? votes.map((vote) => ({ ...vote }))
      : [...votes];
  }

  get poll() {
    return this.args.poll;
  }

  defaultPreloadedVoters() {
    const preloadedVoters = {};

    if (this.poll.public && this.poll.preloaded_voters) {
      Object.keys(this.poll.preloaded_voters).forEach((key) => {
        preloadedVoters[key] = {
          voters: this.poll.preloaded_voters[key],
          loading: false,
        };
      });
    }

    this.options.forEach((option) => {
      if (!preloadedVoters[option.id]) {
        preloadedVoters[option.id] = {
          voters: [],
          loading: false,
        };
      }
    });

    return preloadedVoters;
  }

  get id() {
    return `${this.args.poll.name}-${this.args.post.id}`;
  }

  get post() {
    return this.args.post;
  }

  get groupableUserFields() {
    return this.siteSettings.poll_groupable_user_fields
      .split("|")
      .filter(Boolean);
  }

  get isStaff() {
    return this.currentUser?.staff;
  }

  get titleHTML() {
    return trustHTML(this.args.titleHTML);
  }

  get topicArchived() {
    return this.post.get("topic.archived");
  }

  get isRankedChoice() {
    return this.poll.type === RANKED_CHOICE;
  }

  get staffOnly() {
    return this.poll.results === STAFF_ONLY;
  }

  get isMultiple() {
    return this.poll.type === MULTIPLE;
  }

  get isNumber() {
    return this.poll.type === NUMBER;
  }

  get isMe() {
    return this.currentUser && this.post.user_id === this.currentUser.id;
  }

  get status() {
    return this.poll.status;
  }

  @action
  async castVotes(option) {
    if (!this.canCastVotes) {
      return;
    }

    this.castingVote = true;
    const castVote = this.copyVote(this.vote);

    try {
      const { poll } = await ajax("/polls/vote", {
        type: "PUT",
        data: {
          post_id: this.post.id,
          poll_name: this.poll.name,
          options: castVote,
        },
      });

      this.hasSavedVote = true;
      if (!this.args.post.polls_votes) {
        this.args.post.polls_votes = trackedObject();
      }
      this.args.post.polls_votes[this.poll.name] = castVote;
      this.poll.inProgressVote = undefined;
      Object.assign(this.poll, poll);

      this.appEvents.trigger("poll:voted", poll, this.post, castVote);

      if (this.poll.results !== ON_CLOSE) {
        this.showResults = true;
      }

      if (this.poll.results === STAFF_ONLY) {
        if (this.currentUser && this.currentUser.staff) {
          this.showResults = true;
        } else {
          this.showResults = false;
        }
      }

      this.isAmendingVote = false;
      this.focusCurrentView();
    } catch (error) {
      if (error) {
        if (!this.isMultiple && !this.isRankedChoice) {
          this._toggleOption(option);
        }
        popupAjaxError(error);
      } else {
        this.dialog.alert(i18n("poll.error_while_casting_votes"));
      }
    } finally {
      this.castingVote = false;
    }
  }

  get options() {
    let enrichedOptions = this.poll.options;

    if (this.isRankedChoice) {
      enrichedOptions.forEach((candidate) => {
        const chosenIdx = this.vote.findIndex(
          (object) => object.digest === candidate.id
        );
        if (chosenIdx === -1) {
          candidate.rank = 0;
        } else {
          candidate.rank = this.vote[chosenIdx].rank;
        }
      });
    }

    return enrichedOptions;
  }

  get voters() {
    return this.poll.voters;
  }

  get rankedChoiceOutcome() {
    return this.poll.ranked_choice_outcome || null;
  }

  get #bounds() {
    return pollBounds(this.poll, this.poll.options?.length ?? 0);
  }

  get min() {
    return this.#bounds.min;
  }

  get max() {
    return this.#bounds.max;
  }

  get closed() {
    return this.status === CLOSED_STATUS || this.isAutomaticallyClosed;
  }

  @cached
  get closesAt() {
    return this.poll.close
      ? moment.utc(this.poll.close, "YYYY-MM-DD HH:mm:ss Z")
      : null;
  }

  get isAutomaticallyClosed() {
    return this.closesAt !== null && this.closesAt.valueOf() <= Date.now();
  }

  get hasVoted() {
    return this.vote?.length > 0;
  }

  get hideResultsDisabled() {
    return !this.staffOnly && (this.closed || this.topicArchived);
  }

  @action
  async toggleOption(option, rank = 0) {
    if (this.closed) {
      return;
    }

    if (!this.currentUser) {
      // Archived topics reject votes server-side, so don't queue them.
      // Closed topics still accept votes from regular users, so let anon
      // queue and replay after login.
      if (this.post?.topic?.archived) {
        return;
      }
      if (!this.isMultiple && !this.isRankedChoice) {
        return deferAnonymousAction(this, "vote_poll", {
          post_id: this.post.id,
          poll_name: this.poll.name,
          options: [option.id],
        });
      }
      // Multi-choice / ranked-choice anonymous votes can't be saved on a
      // single click since the selection isn't complete until "Cast Votes".
      getOwner(this).lookup("route:application").send("showLogin");
      return;
    }

    if (!this.checkUserGroups(this.currentUser, this.poll)) {
      return;
    }

    if (
      !this.isMultiple &&
      !this.isRankedChoice &&
      this.vote.length === 1 &&
      this.vote[0] === option.id
    ) {
      if (this.isAmendingVote) {
        return this.keepVote();
      }
      return this.removeVote();
    }

    if (!this.isMultiple && !this.isRankedChoice) {
      this.vote.length = 0;
    }

    this._toggleOption(option, rank);

    if (!this.isMultiple && !this.isRankedChoice) {
      this.castVotes(option);
    }
  }

  @afterRender
  focusCurrentView() {
    this.pollButtonsElement
      ?.closest(".poll")
      ?.querySelector(
        this.showVotedChoices ? ".amend-vote" : "[data-poll-option-id] button"
      )
      ?.focus();
  }

  preserveButtonsPosition(callback) {
    const anchor = this.pollButtonsElement;
    const anchorTop = anchor?.getBoundingClientRect().top;

    callback();

    if (anchorTop == null) {
      return;
    }

    schedule("afterRender", () => {
      if (!anchor.isConnected) {
        return;
      }

      const shift = anchor.getBoundingClientRect().top - anchorTop;
      if (shift !== 0) {
        window.scrollBy(0, shift);
      }
    });
  }

  @action
  toggleResults() {
    this.preserveButtonsPosition(() => {
      this.showResults = !this.showResults;
    });
  }

  @action
  amendVote() {
    this.preserveButtonsPosition(() => {
      this.isAmendingVote = true;
    });
    this.focusCurrentView();
  }

  @action
  keepVote() {
    this.preserveButtonsPosition(() => {
      this._vote = this.savedVote;
      this.poll.inProgressVote = undefined;
      this.isAmendingVote = false;
    });
    this.focusCurrentView();
  }

  get isVoteDirty() {
    const key = (votes) =>
      (this.isRankedChoice
        ? votes
            .filter((vote) => vote.rank !== 0)
            .map((vote) => `${vote.digest}:${vote.rank}`)
        : [...votes]
      )
        .sort()
        .join();

    return key(this.rawSavedVote) !== key(this.vote);
  }

  get canCastVotes() {
    if (this.closed || this.castingVote || !this.currentUser) {
      return false;
    }

    if (this.hasSavedVote && !this.isVoteDirty) {
      return false;
    }

    const selectedOptionCount = this.vote?.length || 0;

    if (this.isMultiple) {
      return selectedOptionCount >= this.min && selectedOptionCount <= this.max;
    }

    if (this.isRankedChoice) {
      return (
        this.options.length === this.vote?.length &&
        this.areRanksValid(this.vote)
      );
    }

    return selectedOptionCount > 0;
  }

  get notInVotingGroup() {
    return !this.checkUserGroups(this.currentUser, this.poll);
  }

  get pollGroups() {
    return i18n("poll.results.groups.title", { groups: this.poll.groups });
  }

  get showCastVotesButton() {
    return (
      (this.isMultiple || this.isRankedChoice) &&
      !this.showResults &&
      !this.showVotedChoices
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

  get castVotesButtonLabel() {
    return i18n(
      this.hasSavedVote
        ? "poll.cast-votes.update_label"
        : "poll.cast-votes.label"
    );
  }

  get castVotesButtonTitle() {
    return i18n(
      this.hasSavedVote
        ? "poll.cast-votes.update_title"
        : "poll.cast-votes.title"
    );
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
      this.resultsToggleAllowed &&
      !(this.poll.results === ON_VOTE && !this.hasSavedVote && !this.isMe) &&
      this.voters > 0
    );
  }

  get canChangeVote() {
    return !this.closed && !this.hideResultsDisabled;
  }

  get showRemoveVoteButton() {
    return (
      this.canChangeVote &&
      !this.showResults &&
      this.hasSavedVote &&
      !this.showVotedChoices
    );
  }

  get showAmendVoteButton() {
    return this.canChangeVote && this.showVotedChoices;
  }

  get showKeepVoteButton() {
    return this.hasHiddenSavedVote && this.isAmendingVote;
  }

  get isCheckbox() {
    return this.isMultiple;
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

    return trustHTML(i18n("poll.average_rating", { average }));
  }

  get availableDisplayMode() {
    if (
      !this.showResults ||
      this.poll.chart_type === PIE_CHART_TYPE ||
      ![REGULAR_POLL_TYPE, MULTIPLE_POLL_TYPE].includes(this.poll.type)
    ) {
      return null;
    }
    return this.showTally ? "showPercentage" : "showTally";
  }

  @action
  updatedVoters() {
    if (!this.voterListExpanded) {
      this.preloadedVoters = this.defaultPreloadedVoters();
    }
  }

  @action
  fetchVoters(optionId) {
    let voters;
    let preloadedVoters = this.preloadedVoters;

    if (optionId) {
      preloadedVoters[optionId].loading = true;
      voters = preloadedVoters[optionId]?.voters;
    } else {
      voters = preloadedVoters;
    }

    this.preloadedVoters = { ...preloadedVoters };
    const votersCount = voters?.length;

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
        this.voterListExpanded = true;
        const newVoters = optionId ? result.voters[optionId] : result.voters;
        let votersSet = new Set([]);

        if (this.isRankedChoice) {
          votersSet = new Set(voters.map((voter) => voter.user.username));
          newVoters.forEach((voter) => {
            if (!votersSet.has(voter.user.username)) {
              votersSet.add(voter.user.username);
              voters.push(voter);
            }
          });
        } else {
          votersSet = new Set(voters.map((voter) => voter.username));
          newVoters.forEach((voter) => {
            if (!votersSet.has(voter.username)) {
              votersSet.add(voter.username);
              voters.push(voter);
            }
          });
          // remove users who changed their vote
          if (this.poll.type === REGULAR) {
            Object.keys(preloadedVoters).forEach((otherOptionId) => {
              if (optionId !== otherOptionId) {
                preloadedVoters[otherOptionId].voters = preloadedVoters[
                  otherOptionId
                ].voters.filter((voter) => !votersSet.has(voter.username));
              }
            });
          }
        }
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(i18n("poll.error_while_fetching_voters"));
        }
      })
      .finally(() => {
        if (optionId) {
          preloadedVoters[optionId].loading = false;
        }
        this.preloadedVoters = { ...preloadedVoters };
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
        if (this.poll.type === RANKED_CHOICE) {
          poll.options.forEach((option) => {
            option.rank = 0;
          });
        }
        this.vote = Object.assign([]);
        this.hasSavedVote = false;
        if (this.args.post.polls_votes) {
          delete this.args.post.polls_votes[this.poll.name];
        }
        this.poll.inProgressVote = undefined;
        this.appEvents.trigger("poll:voted", poll, this.post, this.vote);
        this.showResults = false;
        this.isAmendingVote = false;
        this.focusCurrentView();
      })
      .catch((error) => popupAjaxError(error));
  }

  @action
  toggleStatus() {
    if (this.isAutomaticallyClosed) {
      return;
    }

    this.dialog.yesNoConfirm({
      message: i18n(this.closed ? "poll.open.confirm" : "poll.close.confirm"),
      didConfirm: () => {
        const status = this.closed ? OPEN_STATUS : CLOSED_STATUS;
        ajax("/polls/toggle_status", {
          type: "PUT",
          data: {
            post_id: this.post.id,
            poll_name: this.poll.name,
            status,
          },
        })
          .then(({ poll }) => {
            Object.assign(this.poll, poll);

            if (
              this.poll.results === ON_CLOSE ||
              this.poll.results === "always"
            ) {
              this.showResults = this.status === CLOSED_STATUS;
            }

            // Votes are only included in serialized results for results=ON_CLOSE when
            // the poll is closed, so we must refresh the page to pick these up.
            if (
              this.poll.results === ON_CLOSE &&
              this.status === CLOSED_STATUS
            ) {
              this.router.refresh();
            }
          })
          .catch((error) => {
            if (error) {
              popupAjaxError(error);
            } else {
              this.dialog.alert(i18n("poll.error_while_toggling_status"));
            }
          });
      },
    });
  }

  @action
  showBreakdown() {
    this.modal.show(PollBreakdownModal, {
      model: {
        poll: this.poll,
        post: this.post,
      },
    });
  }

  @action
  exportResults() {
    const queryID =
      this.poll.type === RANKED_CHOICE
        ? this.siteSettings.poll_export_ranked_choice_data_explorer_query_id
        : this.siteSettings.poll_export_data_explorer_query_id;

    // This uses the Data Explorer plugin export as CSV route
    // There is detection to check if the plugin is enabled before showing the button
    ajax(`/admin/plugins/discourse-data-explorer/queries/${queryID}/run.csv`, {
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
          this.dialog.alert(i18n("poll.error_while_exporting_results"));
        }
      });
  }

  @action
  toggleDisplayMode() {
    this.showTally = !this.showTally;
  }

  <template>
    <div class="poll">
      <div
        {{didUpdate this.updatedVoters this.poll.preloaded_voters}}
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
                  @isRankedChoice={{this.isRankedChoice}}
                  @isPublic={{this.poll.public}}
                  @postId={{this.post.id}}
                  @vote={{this.vote}}
                  @voters={{this.preloadedVoters}}
                  @votersCount={{this.poll.voters}}
                  @fetchVoters={{this.fetchVoters}}
                  @rankedChoiceOutcome={{this.rankedChoiceOutcome}}
                  @showTally={{this.showTally}}
                />
              {{/if}}
            {{/if}}
          </div>
        {{else if this.showVotedChoices}}
          <PollVotedChoices
            @options={{this.options}}
            @votes={{this.votedChoices}}
            @isRankedChoice={{this.isRankedChoice}}
          />
        {{else}}
          <PollOptions
            @isCheckbox={{this.isCheckbox}}
            @isRankedChoice={{this.isRankedChoice}}
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
        @closesAt={{this.closesAt}}
        @closed={{this.closed}}
        @closedBy={{this.poll.closed_by}}
        @isAutomaticallyClosed={{this.isAutomaticallyClosed}}
        @results={{this.poll.results}}
        @showResults={{this.showResults}}
        @showingVotedChoices={{this.showVotedChoices}}
        @postUserId={{this.poll.post.user_id}}
        @isPublic={{this.poll.public}}
        @isDynamic={{if @isDynamic true this.poll.dynamic}}
        @hasVoted={{this.hasVoted}}
        @voters={{this.voters}}
      />
      <div class="poll-buttons" {{didInsert this.registerPollButtons}}>
        {{#if this.showKeepVoteButton}}
          <button
            class="btn btn-default keep-vote"
            title={{i18n "poll.keep-vote.title"}}
            {{on "click" this.keepVote}}
          >
            {{dIcon "chevron-left"}}
            <span class="d-button-label">{{i18n "poll.keep-vote.label"}}</span>
          </button>
        {{/if}}

        {{#if this.showCastVotesButton}}
          <button
            class={{this.castVotesButtonClass}}
            title={{this.castVotesButtonTitle}}
            disabled={{this.castVotesDisabled}}
            {{on "click" this.castVotes}}
          >
            {{dIcon this.castVotesButtonIcon}}
            <span class="d-button-label">{{this.castVotesButtonLabel}}</span>
          </button>
        {{/if}}

        {{#if this.showRemoveVoteButton}}
          <button
            class="btn btn-default remove-vote"
            title={{i18n "poll.remove-vote.title"}}
            {{on "click" this.removeVote}}
          >
            {{dIcon "arrow-rotate-left"}}
            <span class="d-button-label">{{i18n
                "poll.remove-vote.label"
              }}</span>
          </button>
        {{/if}}

        {{#if this.showAmendVoteButton}}
          <button
            class="btn btn-default amend-vote"
            title={{i18n "poll.amend-vote.title"}}
            {{on "click" this.amendVote}}
          >
            {{dIcon "pencil"}}
            <span class="d-button-label">{{i18n "poll.amend-vote.label"}}</span>
          </button>
        {{/if}}

        {{#if this.showHideResultsButton}}
          <button
            class="btn btn-default toggle-results"
            title={{i18n "poll.hide-results.title"}}
            {{on "click" this.toggleResults}}
          >
            {{dIcon "chevron-left"}}
            <span class="d-button-label">{{i18n
                "poll.hide-results.label"
              }}</span>
          </button>
        {{/if}}

        {{#if this.showShowResultsButton}}
          <button
            class="btn btn-default toggle-results"
            title={{i18n "poll.show-results.title"}}
            {{on "click" this.toggleResults}}
          >
            {{dIcon "chart-bar"}}
            <span class="d-button-label">{{i18n
                "poll.show-results.label"
              }}</span>
          </button>
        {{/if}}

        <PollButtonsDropdown
          @closed={{this.closed}}
          @voters={{this.voters}}
          @isStaff={{this.isStaff}}
          @isMe={{this.isMe}}
          @isRankedChoice={{this.isRankedChoice}}
          @topicArchived={{this.topicArchived}}
          @groupableUserFields={{this.groupableUserFields}}
          @isAutomaticallyClosed={{this.isAutomaticallyClosed}}
          @dropDownClick={{this.dropDownClick}}
          @availableDisplayMode={{this.availableDisplayMode}}
        />
      </div>
    </div>
  </template>
}
