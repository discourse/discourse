import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

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
  @tracked isStaff = this.currentUser && this.currentUser.staff;
  @tracked vote;
  @tracked closed;
  @tracked titleHTML = htmlSafe(this.args.attrs.titleHTML);
  @tracked topicArchived = this.args.attrs.post.get("topic.archived");
  @tracked options = [];
  @tracked poll = this.args.attrs.poll;
  @tracked staffOnly = this.args.attrs.poll.results === "staff_only";
  @tracked isIrv = this.args.attrs.poll.type === "irv";
  @tracked isMultiple = this.args.attrs.poll.type === "multiple";

  @tracked isMultiVoteType = this.isIrv || this.isMultiple;
  @tracked isNumber = this.args.attrs.poll.type === "number";
  @tracked
  hideResultsDisabled = !this.staffOnly && (this.closed || this.topicArchived);
  @tracked showingResults;
  @tracked
  showResults =
    this.showingResults ||
    (this.args.attrs.post.get("topic.archived") && !this.staffOnly) ||
    (this.closed && !this.staffOnly);
  post = this.args.attrs.post;

  irv_dropdown_content = [];

  toggleOption = (option) => {
    if (this.closed) {
      return;
    }
    if (!this.currentUser) {
      return this.showLogin();
    }
    if (!this.checkUserGroups(this.currentUser, this.args.attrs.poll)) {
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
      return this.castVotes().catch(() => this._toggleOption(option));
    }
  };
  showLogin = () => {
    this.register.lookup("route:application").send("showLogin");
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
  castVotes = () => {
    if (!this.canCastVotes()) {
      return;
    }
    if (!this.currentUser) {
      return this.showLogin();
    }

    return ajax("/polls/vote", {
      type: "PUT",
      data: {
        post_id: this.args.attrs.post.id,
        poll_name: this.args.attrs.poll.name,
        options: this.vote,
      },
    })
      .then(({ poll }) => {
        this.args.attrs.hasSavedVote = true;
        this.args.attrs.poll.setProperties(poll);
        this.appEvents.trigger(
          "poll:voted",
          poll,
          this.args.attrs.post,
          this.args.attrs.vote
        );

        if (this.args.attrs.poll.results !== "on_close") {
          this.showResults = true;
        }
        if (this.args.attrs.poll.results === "staff_only") {
          if (this.currentUser && this.currentUser.staff) {
            this.showResults = true;
          } else {
            this.showResults = false;
          }
        }
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_casting_votes"));
        }
      });
  };
  _toggleOption = (option) => {
    let options = this.options;
    let vote = this.vote;

    const chosenIdx = vote.indexOf(option.id);

    if (chosenIdx !== -1) {
      vote.splice(chosenIdx, 1);
    } else {
      vote.push(option.id);
    }

    options.forEach((o, i) => {
      if (vote.includes(options[i].id)) {
        options[i].chosen = true;
      } else {
        options[i].chosen = false;
      }
    });

    this.vote = [...vote];
    this.options = [...options];
  };
  constructor() {
    super(...arguments);
    this.options = this.args.attrs.poll.options;
    this.vote = this.args.attrs.vote;
    this.attributes = this.args.attrs;
    this.min = this.args.attrs.min;
    this.max = this.args.attrs.max;
    this.closed = this.args.attrs.isClosed;
    this.showingResults = false;

    if (this.args.attrs.isIrv) {
      this.irv_dropdown_content.push({
        id: 0,
        name: I18n.t("poll.options.irv.abstain"),
      });
    }

    this.options.forEach((option, i) => {
      option.rank = 0;
      if (this.args.attrs.isIrv) {
        this.irv_dropdown_content.push({ id: i + 1, name: (i + 1).toString() });
      } else {
        if (this.args.attrs.vote.includes(option.id)) {
          option.chosen = true;
        } else {
          option.chosen = false;
        }
      }
    });
  }

  get canCastVotes() {
    if (this.closed || this.showingResults) {
      return false;
    }

    const selectedOptionCount = this.vote.length;

    if (this.isMultiple) {
      return selectedOptionCount >= this.min && selectedOptionCount <= this.max;
    }

    return selectedOptionCount > 0;
  }

  get pollGroups() {
    return I18n.t("poll.results.groups.title", { groups: this.poll.groups });
  }

  get showCastVotesButton() {
    return (
      this.args.attrs.isMultiple ||
      (this.args.attrs.isIrv &&
        !this.hideResultsDisabled &&
        !this.args.attrs.showResults)
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
    return this.args.attrs.showResults && !this.hideResultsDisabled;
  }

  get showShowResultsButton() {
    return !this.args.attrs.showResults && !this.hideResultsDisabled;
  }

  get showRemoveVoteButton() {
    return this.args.attrs.hasSavedVote;
  }

  get showDropdown() {
    return this.getDropdownContent.length > 1;
  }

  get isCheckbox() {
    if (this.isMultiple) {
      return true;
    } else {
      return false;
    }
  }

  getDropdownContent() {
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
  sendRank(option, rank) {
    this.options.forEach((candidate, i) => {
      if (candidate.id === option) {
        this.options[i].rank = rank;
      } else {
        if (candidate.rank === rank) {
          this.options[i].rank = 0;
        }
      }
    });
  }

  @action
  sendCheck(option, value) {
    this.options.forEach((candidate) => {
      if (candidate.id === option) {
        candidate.chosen = value;
      }
    });
  }

  @action
  sendRadioSelect(option) {
    let options = this.options;
    options.forEach((candidate, index) => {
      if (candidate.id === option) {
        options[index].chosen = true;
      } else {
        options[index].chosen = false;
      }
    });
    this.options = [...options];
    this.vote = [option];
    this.chosen = option;
  }

  removeVote() {
    return ajax("/polls/vote", {
      type: "DELETE",
      data: {
        post_id: this.post.id,
        poll_name: this.poll.name,
      },
    })
      .then(({ poll }) => {
        this.poll.setProperties(poll);
        this.vote.length = 0;
        this.hasSavedVote = false;
        this.appEvents.trigger("poll:voted", poll, this.post, this.vote);
      })
      .catch((error) => popupAjaxError(error));
  }
}

// createWidget("discourse-poll-buttons", {
//   tagName: "div.poll-buttons",

//   html(attrs) {
//     const contents = [];
//     const { poll, post } = attrs;
//     const topicArchived = post.get("topic.archived");
//     const closed = attrs.isClosed;
//     const staffOnly = poll.results === "staff_only";
//     const isStaff = this.currentUser && this.currentUser.staff;
//     const isMe = this.currentUser && post.user_id === this.currentUser.id;
//     const this.hideResultsDisabled = !staffOnly && (closed || topicArchived);
//     const dropdown = this.attach("discourse-poll-buttons-dropdown", attrs);
//     const dropdownOptionsCount = dropdown.optionsCount(attrs);

//     if ((attrs.isMultiple || attrs.isIrv) && !hideResultsDisabled && !attrs.showResults) {
//       const castVotesDisabled = !attrs.canCastVotes;
//       contents.push(
//         this.attach("button", {
//           className: `cast-votes ${castVotesDisabled ? "btn-default" : "btn-primary"
//             }`,
//           label: "poll.cast-votes.label",
//           title: "poll.cast-votes.title",
//           icon: castVotesDisabled ? "far-square" : "check",
//           disabled: castVotesDisabled,
//           action: "castVotes",
//         })
//       );
//     }

//     if (attrs.showResults && !hideResultsDisabled) {
//       contents.push(
//         this.attach("button", {
//           className: "btn-default toggle-results",
//           label: "poll.hide-results.label",
//           title: "poll.hide-results.title",
//           icon: "chevron-left",
//           action: "toggleResults",
//         })
//       );
//     }

//     if (!attrs.showResults && !hideResultsDisabled) {
//       let showResultsButton;

//       if (
//         !(poll.results === "on_vote" && !attrs.hasVoted && !isMe) &&
//         !(poll.results === "on_close" && !closed) &&
//         !(poll.results === "staff_only" && !isStaff) &&
//         poll.voters > 0
//       ) {
//         showResultsButton = this.attach("button", {
//           className: "btn-default toggle-results",
//           label: "poll.show-results.label",
//           title: "poll.show-results.title",
//           icon: "chart-bar",
//           action: "toggleResults",
//         });
//       }

//       if (attrs.hasSavedVote) {
//         contents.push(
//           this.attach("button", {
//             className: "btn-default remove-vote",
//             label: "poll.remove-vote.label",
//             title: "poll.remove-vote.title",
//             icon: "undo",
//             action: "removeVote",
//           })
//         );
//       }

//       if (showResultsButton) {
//         contents.push(showResultsButton);
//       }
//     }

//     // only show the dropdown if there's more than 1 button
//     // otherwise just show the button
//     if (dropdownOptionsCount > 1) {
//       contents.push(dropdown);
//     } else if (dropdownOptionsCount === 1) {
//       const singleOptionId = dropdown._buildContent(attrs)[0].id;
//       let singleOption = buttonOptionsMap[singleOptionId];
//       if (singleOptionId === "toggleStatus") {
//         singleOption = closed
//           ? buttonOptionsMap.openPoll
//           : buttonOptionsMap.closePoll;
//       }
//       contents.push(this.attach("button", singleOption));
//     }
//     return [contents];
//   },
// });
