import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { ACTIVITY_FILTERS } from "../../../../../lib/select-fixtures.js";

export default class DefaultsSelectExample extends Component {
  @tracked value = "mentions";

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-content-defaults"
      @items={{ACTIVITY_FILTERS}}
      @labelField="name"
      @onChange={{this.onChange}}
      @selectedIcon="check"
      @value={{this.value}}
    />
  </template>
}
