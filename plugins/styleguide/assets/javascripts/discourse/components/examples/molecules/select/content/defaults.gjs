import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { PEOPLE } from "../../../../../lib/select-fixtures";

export default class DefaultsSelectExample extends Component {
  @tracked value = 102;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-content-defaults"
      @items={{PEOPLE}}
      @labelField="name"
      @onChange={{this.onChange}}
      @selectedIcon="check"
      @value={{this.value}}
    />
  </template>
}
