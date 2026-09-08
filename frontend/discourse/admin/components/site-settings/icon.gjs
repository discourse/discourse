import Component from "@glimmer/component";
import { action } from "@ember/object";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";

export default class Icon extends Component {
  @action
  onChangeIcon(value) {
    this.args.changeValueCallback(value);
  }

  <template>
    <DIconGridPicker
      @disabled={{@disabled}}
      @onChange={{this.onChangeIcon}}
      @onlyAvailable={{false}}
      @showCaret={{true}}
      @showSelectedName={{true}}
      @value={{@value}}
    />
  </template>
}
