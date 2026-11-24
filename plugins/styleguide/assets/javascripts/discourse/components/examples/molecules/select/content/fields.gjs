import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { sortOrders } from "../../../../../lib/select-fixtures.js";

export default class FieldsSelectExample extends Component {
  @tracked value = "latest";

  items = sortOrders();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @descriptionField="summary"
      @iconField="icon"
      @identifier="sg-fields"
      @labelField="name"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
