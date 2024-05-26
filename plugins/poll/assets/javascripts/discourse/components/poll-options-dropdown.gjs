import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

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
  <template>
    <DropdownSelectBox
      @candidate={{@option.id}}
      @value={{this.rank}}
      @content={{@irvDropdownContent}}
      @onChange={{fn this.selectRank @option.id}}
      @options={{hash showCaret=true filterable=false}}
      class="poll-option-dropdown"
    />
  </template>
}
