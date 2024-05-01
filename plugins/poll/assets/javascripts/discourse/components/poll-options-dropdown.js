import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class PollOptionsDropdownComponent extends Component {
  @tracked rank = 0;
  constructor() {
    super(...arguments);
    this.rank = this.args.rank;
  }

  @action
  selectRank(option, rank) {
    this.rank = rank;
    this.args.sendRank(option, rank);
  }

  // get rank() {
  //   return this.args.rank;
  // }
}
