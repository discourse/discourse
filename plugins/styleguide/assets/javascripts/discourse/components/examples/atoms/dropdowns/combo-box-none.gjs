import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import ComboBox from "discourse/select-kit/components/combo-box";

const OPTIONS = [
  { id: 1, name: "Orange" },
  { id: 2, name: "Blue" },
  { id: 3, name: "Red" },
  { id: 4, name: "Yellow" },
];

export default class ComboBoxNoneExample extends Component {
  @tracked value = OPTIONS[0].name;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <ComboBox
      @content={{OPTIONS}}
      @onChange={{this.onChange}}
      @options={{hash none="category.none"}}
      @value={{this.value}}
    />
  </template>
}
