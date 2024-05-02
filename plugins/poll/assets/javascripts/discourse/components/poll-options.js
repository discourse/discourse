import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class PollOptionsComponent extends Component {
  isChosen = (option) => {
    // console.log(option);
    return this.args.votes.includes(option.id);
  };

  @action
  sendClick(option) {
    this.args.sendRadioClick(option);
  }
}
