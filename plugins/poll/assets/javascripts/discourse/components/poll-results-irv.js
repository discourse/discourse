import Component from "@glimmer/component";
import I18n from "discourse-i18n";

export default class PollResultsIrvComponent extends Component {
  get irvWinnerText() {
    return I18n.t("poll.irv.winner", {
      count: this.args.irvOutcome.round_activity.length,
      winner: this.args.irvOutcome.winning_candidate.html,
    });
  }

  get irvTiedText() {
    return I18n.t("poll.irv.tied", {
      count: this.args.irvOutcome.round_activity.length,
    });
  }
}
