import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { topicVisibilities } from "../../../../../lib/select-fixtures.js";

export default class RowIconsSelectExample extends Component {
  @tracked value = "unlisted";

  items = topicVisibilities();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @iconField="icon"
      @identifier="sg-row-icons"
      @labelField="title"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
    />
  </template>
}
