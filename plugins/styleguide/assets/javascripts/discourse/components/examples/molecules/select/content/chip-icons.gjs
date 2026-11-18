import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { USER_GROUPS } from "../../../../../lib/select-fixtures.js";

export default class ChipIconsSelectExample extends Component {
  @tracked value = [1, 3];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @iconField="icon"
      @identifier="sg-chip-icons"
      @labelField="fullName"
      @multiple={{true}}
      @onChange={{this.onChange}}
      @options={{USER_GROUPS}}
      @value={{this.value}}
    />
  </template>
}
