import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class PollOptionsComponent extends Component {
  isChosen = (option) => {
    return this.args.votes.includes(option.id);
  };

  get classes() {
    return this.args.isIrv ? "irv-poll-options" : "";
  }

  @action
  sendClick(option) {
    this.args.sendOptionSelect(option);
  }

  @action
  sendRank(option, rank = 0) {
    this.args.sendOptionSelect(option, rank);
  }
}
