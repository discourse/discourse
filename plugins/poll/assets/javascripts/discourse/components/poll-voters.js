import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

const FETCH_VOTERS_COUNT = 25;

export default class PollVotersComponent extends Component {
  @tracked voters = [];
  @tracked loading = false;

  // get voters() {
  //   return this.args.voters[this.args.optionId] || [];
  constructor() {
    super(...arguments);
    this.voters = this.args.voters[this.args.optionId] || [];
  }
  // }

  get showMore() {
    return this.args.voters.length < this.args.totalVotes;
  }

  @action
  fetchVoters() {
    let votersCount;
    let optionId = this.args.optionId;
    this.loading = true;

    votersCount = this.voters.length;

    return ajax("/polls/voters.json", {
      data: {
        post_id: this.args.postId,
        poll_name: this.args.pollName,
        option_id: optionId,
        page: Math.floor(votersCount / FETCH_VOTERS_COUNT) + 1,
        limit: FETCH_VOTERS_COUNT,
      },
    })
      .then((result) => {
        const voters = optionId ? this.voters[optionId] : this.voters;
        const newVoters = optionId ? result.voters[optionId] : result.voters;
        const votersSet = new Set(voters.map((voter) => voter.username));

        newVoters.forEach((voter) => {
          if (!votersSet.has(voter.username)) {
            votersSet.add(voter.username);
            voters.push(voter);
          }
        });

        // remove users who changed their vote
        if (this.args.pollType === "regular") {
          Object.keys(this.voters).forEach((otherOptionId) => {
            if (optionId !== otherOptionId) {
              this.voters[otherOptionId] = this.voters[otherOptionId].filter(
                (voter) => !votersSet.has(voter.username)
              );
            }
          });
        }

        this.voters = newVoters;
        this.loading = false;
      })
      .catch((error) => {
        if (error) {
          popupAjaxError(error);
        } else {
          this.dialog.alert(I18n.t("poll.error_while_fetching_voters"));
        }
      })
      .finally(() => {
        this.loading = false;
      });
  }
}
