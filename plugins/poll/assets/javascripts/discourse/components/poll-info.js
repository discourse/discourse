import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { relativeAge } from "discourse/lib/formatter";
import I18n from "I18n";

export default class PollInfoComponent extends Component {
  @service currentUser;

  get multipleHelpText() {
    const min = this.args.attrs.min;
    const max = this.args.attrs.max;
    const options = this.args.attrs.poll.options.length;

    if (max > 0) {
      if (min === max) {
        if (min > 1) {
          return htmlSafe(
            I18n.t("poll.multiple.help.x_options", { count: min })
          );
        }
      } else if (min > 1) {
        if (max < options) {
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
      } else if (max <= options) {
        return htmlSafe(
          I18n.t("poll.multiple.help.up_to_max_options", { count: max })
        );
      }
    }
  }

  get votersLabel() {
    return I18n.t("poll.voters", { count: this.args.attrs.poll.voters });
  }

  get showTotalVotes() {
    return (
      this.args.attrs.isMultiple &&
      (this.args.showResults || this.args.attrs.isClosed)
    );
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
    return (
      this.args.attrs.isMultiple &&
      !this.args.showResults &&
      !this.args.attrs.isClosed
    );
  }

  get closeTitle() {
    const closeDate = moment.utc(
      this.args.attrs.poll.close,
      "YYYY-MM-DD HH:mm:ss Z"
    );
    if (closeDate.isValid()) {
      return closeDate.format("LLL");
    } else {
      return "";
    }
  }

  get age() {
    const closeDate = moment.utc(
      this.args.attrs.poll.close,
      "YYYY-MM-DD HH:mm:ss Z"
    );
    if (closeDate.isValid()) {
      return relativeAge(closeDate.toDate(), { addAgo: true });
    } else {
      return 0;
    }
  }

  get timeLeft() {
    const closeDate = moment.utc(
      this.args.attrs.poll.close,
      "YYYY-MM-DD HH:mm:ss Z"
    );
    if (closeDate.isValid()) {
      return moment().to(closeDate, true);
    } else {
      return 0;
    }
  }

  get resultsOnVote() {
    return (
      this.args.attrs.poll.results === "on_vote" &&
      !this.args.attrs.hasVoted &&
      !(
        this.currentUser &&
        this.args.attrs.poll.post.user_id === this.currentUser.id
      )
    );
  }

  get resultsOnClose() {
    return (
      this.args.attrs.poll.results === "on_close" && !this.args.attrs.isClosed
    );
  }

  get resultsStaffOnly() {
    return (
      this.args.attrs.poll.results === "staff_only" &&
      !(this.currentUser && this.currentUser.staff)
    );
  }

  get publicTitle() {
    return (
      !this.args.attrs.isClosed &&
      !this.args.showResults &&
      this.args.attrs.poll.public &&
      this.args.attrs.poll.results !== "staff_only"
    );
  }

  get publicTitleLabel() {
    return htmlSafe(I18n.t("poll.public.title"));
  }

  get showInstructionsSection() {
    if (
      this.showMultipleHelpText ||
      this.args.attrs.poll.close ||
      this.resultsOnVote ||
      this.resultsOnClose ||
      this.resultsStaffOnly ||
      this.publicTitle
    ) {
      return true;
    }
  }
}
