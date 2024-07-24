import { hbs } from "ember-cli-htmlbars";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";

const STAFF_ONLY = "staff_only";
const REGULAR = "regular";
const MULTIPLE = "multiple";
const NUMBER = "number";
const RANKED_CHOICE = "ranked_choice";
const FETCH_VOTERS_COUNT = 25;

export default createWidget("discourse-poll", {
  tagName: "div",
  buildKey: (attrs) => `poll-${attrs.id}`,
  services: ["dialog"],

  buildAttributes(attrs) {
    let cssClasses = "poll-outer";
    if (attrs.poll.chart_type === PIE_CHART_TYPE) {
      cssClasses += " pie";
    }
    return {
      class: cssClasses,
      "data-poll-name": attrs.poll.name,
      "data-poll-type": attrs.poll.type,
    };
  },

  defaultState(attrs) {
    return {
      id: attrs.id,
      poll: attrs.poll,
      titleHTML: attrs.titleHTML,
      isRankedChoice: attrs.poll.type === RANKED_CHOICE,
      isMultiple: attrs.poll.type === MULTIPLE,
      isNumber: attrs.poll.type === NUMBER,
      post: attrs.post,
      status: attrs.poll.status,
      closed: this.closed(attrs),
      topicArchived: this.topicArchived(attrs),
      staffOnly: this.staffOnly(attrs),
      rankedChoiceDropdownContent: this.setupRankedChoiceDropdownContent(attrs),
      voters: attrs.poll.voters,
      vote: attrs.vote,
      hasSavedVote: attrs.hasSavedVote,
      options: attrs.poll.options,
      preloadedVoters: this.populatePreloadedVoters(attrs),
      groupableUserFields: attrs.groupableUserFields,
      rankedChoiceOutcome: attrs.poll.ranked_choice_outcome || [],
    };
  },

  populatePreloadedVoters(attrs) {
    let preloadedVoters = {};

    if (attrs.poll.public) {
      Object.keys(attrs.poll.preloaded_voters).forEach((key) => {
        preloadedVoters[key] = {
          voters: attrs.poll.preloaded_voters[key],
          loading: false,
        };
      });
    }

    return preloadedVoters;
  },

  closed(attrs) {
    return attrs.poll.status === "closed" || this.isAutomaticallyClosed(attrs);
  },

  topicArchived(attrs) {
    return attrs.post.get("topic.archived");
  },

  staffOnly(attrs) {
    return attrs.poll.results === STAFF_ONLY;
  },

  setupRankedChoiceDropdownContent(attrs) {
    let rankedChoiceDropdownContent = [];

    rankedChoiceDropdownContent.push({
      id: 0,
      name: I18n.t("poll.options.ranked_choice.abstain"),
    });

    attrs.poll.options.forEach((option, i) => {
      option.rank = 0;
      rankedChoiceDropdownContent.push({
        id: i + 1,
        name: (i + 1).toString(),
      });
    });

    return rankedChoiceDropdownContent;
  },

  isAutomaticallyClosed(attrs) {
    const poll = attrs.poll;
    return (
      (poll.close ?? false) &&
      moment.utc(poll.close, "YYYY-MM-DD HH:mm:ss Z") <= moment()
    );
  },

  toggleStatus() {
    this.dialog.yesNoConfirm({
      message: I18n.t(
        this.state.closed ? "poll.open.confirm" : "poll.close.confirm"
      ),
      didConfirm: () => {
        const status = this.state.closed ? "open" : "closed";
        ajax("/polls/toggle_status", {
          type: "PUT",
          data: {
            post_id: this.state.post.id,
            poll_name: this.state.poll.name,
            status,
          },
        })
          .then(() => {
            this.state.poll.status = status;
            this.state.status = status;
            this.state.closed = status === "closed";
          })
          .catch((error) => {
            if (error) {
              popupAjaxError(error);
            } else {
              this.dialog.alert(I18n.t("poll.error_while_toggling_status"));
            }
          })
          .finally(() => {
            this.scheduleRerender();
            return status;
          });
      },
    });
  },

  toggleOption(option, rank = 0) {
    let options = this.state.options;
    let vote = this.state.vote;

    if (this.state.isMultiple) {
      const chosenIdx = vote.indexOf(option.id);

      if (chosenIdx !== -1) {
        vote.splice(chosenIdx, 1);
      } else {
        vote.push(option.id);
      }
    } else if (this.state.isRankedChoice) {
      options.forEach((candidate, i) => {
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
            options[i].rank = rank;
          }
        }
      });
    } else {
      vote = [option.id];
    }

    this.state.vote = [...vote];
    this.state.options = [...options];
    this.scheduleRerender();
  },

  castVotes() {
    let successfulVote = false;
    return ajax("/polls/vote", {
      type: "PUT",
      data: {
        post_id: this.state.post.id,
        poll_name: this.state.poll.name,
        options: this.state.vote,
      },
    })
      .then(({ poll }) => {
        this.state.options = [...poll.options];
        this.state.hasSavedVote = true;
        this.state.rankedChoiceOutcome = poll.ranked_choice_outcome || [];
        this.state.poll.setProperties(poll);
        this.appEvents.trigger(
          "poll:voted",
          poll,
          this.state.post,
          this.state.vote
        );

        const voters = poll.voters;
        this.state.voters = [Number(voters)][0];
        successfulVote = true;
      })
      .catch((error) => {
        successfulVote = false;
        if (error) {
          if (!this.state.isMultiple && !this.state.isRankedChoice) {
            // this._toggleOption(option);
          }
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_casting_votes"));
        }
      })
      .finally(() => {
        this.scheduleRerender();
        return successfulVote;
      });
  },

  removeVote() {
    let successfulRetraction = false;
    return ajax("/polls/vote", {
      type: "DELETE",
      data: {
        post_id: this.state.post.id,
        poll_name: this.state.poll.name,
      },
    })
      .then(({ poll }) => {
        if (this.state.poll.type === RANKED_CHOICE) {
          poll.options.forEach((option) => {
            option.rank = 0;
          });
        }
        this.state.options = [...poll.options];
        this.state.poll.setProperties(poll);
        this.state.rankedChoiceOutcome = poll.ranked_choice_outcome || [];
        this.state.vote = [];
        this.state.voters = poll.voters;
        this.state.hasSavedVote = false;
        this.appEvents.trigger(
          "poll:voted",
          poll,
          this.state.post,
          this.state.vote
        );
        successfulRetraction = true;
      })
      .catch((error) => {
        popupAjaxError(error);
      })
      .finally(() => {
        this.scheduleRerender();
        return successfulRetraction;
      });
  },

  fetchVoters(optionId) {
    let votersCount;
    let preloadedVoters = this.state.preloadedVoters;

    Object.keys(preloadedVoters).forEach((key) => {
      if (key === optionId) {
        preloadedVoters[key].loading = true;
      }
    });

    this.state.preloadedVoters = Object.assign(preloadedVoters);

    votersCount = this.state.options.find(
      (option) => option.id === optionId
    ).votes;

    return ajax("/polls/voters.json", {
      data: {
        post_id: this.state.post.id,
        poll_name: this.state.poll.name,
        option_id: optionId,
        page: Math.floor(votersCount / FETCH_VOTERS_COUNT) + 1,
        limit: FETCH_VOTERS_COUNT,
      },
    })
      .then((result) => {
        const voters =
          (optionId
            ? this.state.preloadedVoters[optionId].voters
            : this.state.preloadedVoters) || [];

        const newVoters = optionId ? result.voters[optionId] : result.voters;
        if (this.state.isRankedChoice) {
          this.state.preloadedVoters[optionId] = [...new Set([...newVoters])];
        } else {
          const votersSet = new Set(voters.map((voter) => voter.username));
          newVoters.forEach((voter) => {
            if (!votersSet.has(voter.username)) {
              votersSet.add(voter.username);
              voters.push(voter);
            }
          });
          // remove users who changed their vote
          if (this.state.poll.type === REGULAR) {
            Object.keys(this.state.preloadedVoters).forEach((otherOptionId) => {
              if (optionId !== otherOptionId) {
                this.state.preloadedVoters[otherOptionId].voters =
                  this.state.preloadedVoters[otherOptionId].voters.filter(
                    (voter) => !votersSet.has(voter.username)
                  );
              }
            });
          }
        }
        const combinedArray = [
          ...this.state.preloadedVoters[optionId].voters,
          ...newVoters,
        ];

        const uniqueUsers = combinedArray.reduce((acc, user) => {
          acc[user.username] = user;
          return acc;
        }, {});

        const uniqueArray = Object.values(uniqueUsers);

        preloadedVoters = {
          voters: uniqueArray,
          loading: false,
        };

        this.state.preloadedVoters[optionId] = Object.assign(preloadedVoters);
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_fetching_voters"));
        }
      })
      .finally(() => {
        // this.state.preloadedVoters = preloadedVoters;
        this.scheduleRerender();
      });
  },

  html(attrs) {
    this.state.options = attrs.poll.options;
    this.state.preloadedVoters = this.populatePreloadedVoters(attrs);
    if (this.state.isRankedChoice) {
      this.state.rankedChoiceOutcome = attrs.poll.ranked_choice_outcome || [];
    }
    attrs.poll.options.forEach((option) => {
      option.rank = 0;
      if (this.state.isRankedChoice) {
        this.state.vote.forEach((vote) => {
          if (vote.digest === option.id) {
            option.rank = vote.rank;
          }
        });
      }
    });

    return [
      new RenderGlimmer(
        this,
        "div.poll",
        hbs`<Poll
          @attrs={{@data.attrs}}
          @id={{@data.id}}
          @poll={{@data.poll}}
          @post={{@data.post}}
          @titleHTML={{@data.titleHTML}}
          @isRankedChoice={{@data.isRankedChoice}}
          @isMultiple={{@data.isMultiple}}
          @isNumber={{@data.isNumber}}
          @status={{@data.status}}
          @closed={{@data.closed}}
          @topicArchived={{@data.topicArchived}}
          @staffOnly={{@data.staffOnly}}
          @preloadedVoters={{@data.preloadedVoters}}
          @options={{@data.options}}
          @voters={{@data.voters}}
          @vote={{@data.vote}}
          @rankedChoiceDropdownContent={{@data.rankedChoiceDropdownContent}}
          @hasSavedVote={{@data.hasSavedVote}}
          @rankedChoiceOutcome={{@data.rankedChoiceOutcome}}
          @groupableUserFields={{@data.groupableUserFields}}
          @removeVote={{action @data.removeVote}}
          @castVotes={{action @data.castVotes}}
          @toggleStatus={{action @data.toggleStatus}}
          @toggleOption={{action @data.toggleOption}}
          @fetchVoters={{action @data.fetchVoters}}
        />`,
        {
          attrs,
          id: this.state.id,
          poll: this.state.poll,
          titleHTML: this.state.titleHTML,
          isRankedChoice: this.state.isRankedChoice,
          isMultiple: this.state.isMultiple,
          isNumber: this.state.isNumber,
          post: this.state.post,
          status: this.state.status,
          closed: this.state.closed,
          topicArchived: this.state.topicArchived,
          staffOnly: this.state.staffOnly,
          options: this.state.options,
          voters: attrs.poll.voters,
          vote: this.state.vote,
          preloadedVoters: this.state.preloadedVoters,
          rankedChoiceDropdownContent: this.state.rankedChoiceDropdownContent,
          hasSavedVote: this.state.hasSavedVote,
          rankedChoiceOutcome: this.state.rankedChoiceOutcome,
          groupableUserFields: this.state.groupableUserFields,
          removeVote: this.removeVote.bind(this),
          castVotes: this.castVotes.bind(this),
          toggleStatus: this.toggleStatus.bind(this),
          toggleOption: this.toggleOption.bind(this),
          fetchVoters: this.fetchVoters.bind(this),
        }
      ),
    ];
  },
});
