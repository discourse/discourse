import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import Poll from "../components/poll";

const STAFF_ONLY = "staff_only";
const CLOSED = "closed";
const ON_CLOSE = "on_close";
const REGULAR = "regular";
const MULTIPLE = "multiple";
const NUMBER = "number";
const RANKED_CHOICE = "ranked_choice";
const FETCH_VOTERS_COUNT = 25;

export default class PollWrapperComponent extends Component {
  @service currentUser;
  @service appEvents;
  @service dialog;

  @tracked status = this.args.attrs.poll.status;
  @tracked
  closed = this.args.attrs.poll.status === CLOSED || this.isAutomaticallyClosed;
  @tracked hasSavedVote = this.args.attrs.hasSavedVote;
  @tracked vote = this.args.attrs.vote;
  @tracked loading = false;
  @tracked showResults = this.defaultShowResults();
  @tracked preloadedVoters = this.defaultPreloadedVoters();
  id = this.args.attrs.id;
  post = this.args.attrs.post;
  poll = this.args.attrs.poll;
  titleHTML = this.args.attrs.titleHTML;
  isRankedChoice = this.args.attrs.poll.type === RANKED_CHOICE;
  isMultiple = this.args.attrs.poll.type === MULTIPLE;
  isNumber = this.args.attrs.poll.type === NUMBER;
  groupableUserFields = this.args.attrs.groupableUserFields;

  get options() {
    return this.args.attrs.poll.options;
  }

  get enrichedOptions() {
    let enrichedOptions = this.options;

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
    return this.args.attrs.poll.voters;
  }

  get rankedChoiceOutcome() {
    return this.args.attrs.poll.ranked_choice_outcome || [];
  }

  defaultShowResults() {
    const closed = this.closed;
    const staffOnly = this.staffOnly;
    const topicArchived = this.topicArchived;
    const resultsOnClose = this.args.attrs.poll.results === ON_CLOSE;

    return (
      !(resultsOnClose && !closed) &&
      (this.args.attrs.hasSavedVote ||
        (resultsOnClose && closed) ||
        (topicArchived && !staffOnly) ||
        (closed && !staffOnly))
    );
  }

  defaultPreloadedVoters() {
    let preloadedVoters = {};

    if (this.args.attrs.poll.public && this.args.attrs.poll.preloaded_voters) {
      Object.keys(this.args.attrs.poll.preloaded_voters).forEach((key) => {
        preloadedVoters[key] = {
          voters: this.args.attrs.poll.preloaded_voters[key],
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

  get topicArchived() {
    return this.args.attrs.post.get("topic.archived");
  }

  get staffOnly() {
    return this.args.attrs.poll.results === STAFF_ONLY;
  }

  get rankedChoiceDropdownContent() {
    let rankedChoiceDropdownContent = [];

    rankedChoiceDropdownContent.push({
      id: 0,
      name: I18n.t("poll.options.ranked_choice.abstain"),
    });

    this.args.attrs.poll.options.forEach((option, i) => {
      option.rank = 0;
      rankedChoiceDropdownContent.push({
        id: i + 1,
        name: (i + 1).toString(),
      });
    });

    return rankedChoiceDropdownContent;
  }

  get isAutomaticallyClosed() {
    const poll = this.args.attrs.poll;
    return (
      (poll.close ?? false) &&
      moment.utc(poll.close, "YYYY-MM-DD HH:mm:ss Z") <= moment()
    );
  }

  @action
  toggleStatus() {
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
            this.closed = status === "closed";
            if (
              this.poll.results === "on_close" ||
              this.poll.results === "always"
            ) {
              this.showResults = status === "closed";
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
  toggleResults() {
    const showResults = !this.showResults;
    this.showResults = showResults;
  }

  @action
  toggleOption(option, rank = 0) {
    let vote = this.vote;

    if (this.isMultiple) {
      const chosenIdx = vote.indexOf(option.id);

      if (chosenIdx !== -1) {
        vote.splice(chosenIdx, 1);
      } else {
        vote.push(option.id);
      }
    } else if (this.isRankedChoice) {
      this.options.forEach((candidate) => {
        const chosenIdx = vote.findIndex(
          (object) => object.digest === candidate.id
        );

        if (chosenIdx === -1) {
          vote.push({
            digest: candidate.id,
            rank: candidate.id === option ? rank : 0,
          });
        } else {
          if (candidate.id === option) {
            vote[chosenIdx].rank = rank;
          }
        }
      });
    } else {
      vote = [option.id];
    }

    this.vote = [...vote];
  }

  @action
  castVotes() {
    return ajax("/polls/vote", {
      type: "PUT",
      data: {
        post_id: this.post.id,
        poll_name: this.poll.name,
        options: this.vote,
      },
    })
      .then(({ poll }) => {
        this.hasSavedVote = true;
        this.poll.setProperties(poll);
        this.appEvents.trigger("poll:voted", poll, this.post, this.vote);

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
          if (!this.isMultiple && !this.isRankedChoice) {
            this.vote = [...this.vote];
          }
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_casting_votes"));
        }
      });
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
        this.appEvents.trigger("poll:voted", poll, this.post, this.vote);
        this.showResults = false;
      })
      .catch((error) => {
        popupAjaxError(error);
      });
  }

  @action
  fetchVoters(optionId) {
    let votersCount;
    let preloadedVoters = this.preloadedVoters;

    Object.keys(preloadedVoters).forEach((key) => {
      if (key === optionId) {
        preloadedVoters[key].loading = true;
      }
    });

    this.preloadedVoters = Object.assign(preloadedVoters);

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
        const voters =
          (optionId
            ? this.preloadedVoters[optionId].voters
            : this.preloadedVoters) || [];

        const newVoters = optionId ? result.voters[optionId] : result.voters;
        if (this.isRankedChoice) {
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
          if (this.poll.type === REGULAR) {
            Object.keys(this.preloadedVoters).forEach((otherOptionId) => {
              if (optionId !== otherOptionId) {
                this.preloadedVoters[otherOptionId].voters =
                  this.preloadedVoters[otherOptionId].voters.filter(
                    (voter) => !votersSet.has(voter.username)
                  );
              }
            });
          }
        }
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_fetching_voters"));
        }
      })
      .finally(() => {
        preloadedVoters = this.preloadedVoters;
        preloadedVoters[optionId].loading = false;
        this.preloadedVoters = Object.assign(preloadedVoters);
      });
  }

  <template>
    {{log this.args.attrs.vote}}
    {{log this.vote}}
    {{log this.args.attrs.poll.voters}}
    {{log this.voters}}
    <Poll
      @attrs={{@attrs}}
      @id={{this.id}}
      @poll={{this.poll}}
      @post={{this.post}}
      @titleHTML={{this.titleHTML}}
      @isRankedChoice={{this.isRankedChoice}}
      @isMultiple={{this.isMultiple}}
      @isNumber={{this.isNumber}}
      @status={{this.status}}
      @showResults={{this.showResults}}
      @closed={{this.closed}}
      @topicArchived={{this.topicArchived}}
      @staffOnly={{this.staffOnly}}
      @preloadedVoters={{this.preloadedVoters}}
      @options={{this.enrichedOptions}}
      @voters={{this.voters}}
      @vote={{this.vote}}
      @rankedChoiceDropdownContent={{this.rankedChoiceDropdownContent}}
      @hasSavedVote={{this.hasSavedVote}}
      @rankedChoiceOutcome={{this.rankedChoiceOutcome}}
      @groupableUserFields={{this.groupableUserFields}}
      @removeVote={{this.removeVote}}
      @castVotes={{this.castVotes}}
      @toggleStatus={{this.toggleStatus}}
      @toggleOption={{this.toggleOption}}
      @toggleResults={{this.toggleResults}}
      @fetchVoters={{this.fetchVoters}}
    />\`
  </template>
}
