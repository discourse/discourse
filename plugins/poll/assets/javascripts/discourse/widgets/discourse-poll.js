import { hbs } from "ember-cli-htmlbars";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";

const STAFF_ONLY = "staff_only";
const MULTIPLE = "multiple";
const NUMBER = "number";
const RANKED_CHOICE = "ranked_choice";

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
      voters: attrs.poll.voters,
      vote: attrs.vote,
      hasSavedVote: attrs.hasSavedVote,
      options: attrs.poll.options,
      preloaded_voters: attrs.poll.preloaded_voters,
      groupableUserFields: attrs.groupableUserFields,
      rankedChoiceOutcome: attrs.rankedChoiceOutcome || [],
    };
  },

  closed(attrs) {
    return attrs.status === "closed" || this.isAutomaticallyClosed(attrs);
  },

  topicArchived(attrs) {
    return attrs.post.get("topic.archived");
  },

  staffOnly(attrs) {
    return attrs.poll.results === STAFF_ONLY;
  },

  isAutomaticallyClosed(attrs) {
    const poll = attrs.poll;
    return (
      (poll.close ?? false) &&
      moment.utc(poll.close, "YYYY-MM-DD HH:mm:ss Z") <= moment()
    );
  },

  updatedVoters() {
    // this.preloadedVoters = this.args.preloadedVoters;
    // this.options = [...this.args.options];
    if (this.isRankedChoice) {
      this.options.forEach((candidate) => {
        let specificVote = this.vote.find(
          (vote) => vote.digest === candidate.id
        );
        let rank = specificVote ? specificVote.rank : 0;
        candidate.rank = rank;
      });
    }
  },

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
            post_id: this.attrs.post.id,
            poll_name: this.state.poll.name,
            status,
          },
        })
          .then(() => {
            this.state.poll.status = status;
            this.state.status = status;
            if (
              this.state.poll.results === "on_close" ||
              this.state.poll.results === "always"
            ) {
              this.state.showResults = this.state.status === "closed";
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
  },

  castVotes() {
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
        // this.state.vote = this.attrs.vote;
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
        this.scheduleRerender();
        return true;
      })
      .catch((error) => {
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
        return false;
      });
  },

  removeVote() {
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
        return true;
      })
      .catch((error) => {
        popupAjaxError(error);
      })
      .finally(() => {
        return false;
      });
  },

  html(attrs) {
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
          @voters={{@data.voters}}
          @vote={{@data.vote}}
          @preloadedVoters={{@data.preloadedVoters}}
          @options={{@data.options}}
          @hasSavedVote={{@data.hasSavedVote}}
          @rankedChoiceOutcome={{@data.rankedChoiceOutcome}}
          @groupableUserFields={{@data.groupableUserFields}}
          @removeVote={{action @data.removeVote}}
          @castVotes={{action @data.castVotes}}
          @toggleStatus={{action @data.toggleStatus}}
          @toggleOption={{action @data.toggleOption}}
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
          options: attrs.poll.options,
          voters: attrs.poll.voters,
          vote: this.state.vote,
          preloadedVoters: this.state.preloaded_voters,
          hasSavedVote: this.state.hasSavedVote,
          rankedChoiceOutcome: this.state.rankedChoiceOutcome,
          groupableUserFields: this.state.groupableUserFields,
          removeVote: this.removeVote.bind(this),
          castVotes: this.castVotes.bind(this),
          toggleStatus: this.toggleStatus.bind(this),
          toggleOption: this.toggleOption.bind(this),
        }
      ),
    ];
  },
});
