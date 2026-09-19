import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ComboBox from "discourse/select-kit/components/combo-box";

export default class ComboBoxFilterableExample extends Component {
  @tracked value = this.args.categories?.[0]?.name;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <ComboBox
      @content={{@categories}}
      @onChange={{this.onChange}}
      @options={{hash filterable=true}}
      @value={{this.value}}
    />
  </template>
}
