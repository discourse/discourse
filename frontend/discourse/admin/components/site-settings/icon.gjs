import Component from "@glimmer/component";
import { action } from "@ember/object";
import DIconGridPicker from "discourse/components/d-icon-grid-picker";

export default class Icon extends Component {
  @action
  onChangeIcon(value) {
    this.args.changeValueCallback(value);
  }

  <template>
    <DIconGridPicker
      @value={{@value}}
      @onChange={{this.onChangeIcon}}
      @disabled={{@disabled}}
      @showCaret={{true}}
      @showSelectedName={{true}}
    />
  </template>
}
