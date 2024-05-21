import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
export default class PollOptionsComponent extends Component {
  @service currentUser;

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
