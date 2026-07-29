import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { USER_GROUPS } from "../../../../../lib/select-fixtures";

export default class ChipIconsSelectExample extends Component {
  @tracked value = [1, 3];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-chip-icons"
      @items={{USER_GROUPS}}
      @multiple={{true}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @labelField="fullName"
    >
      <:item as |group|>
        <span class="select-examples__row">
          {{dIcon group.icon}}
          <span class="select-examples__primary">{{group.fullName}}</span>
        </span>
      </:item>
      <:selection as |group|>
        <span class="select-examples__chip">
          {{dIcon group.icon}}
          {{group.fullName}}
        </span>
      </:selection>
    </DSelect>
  </template>
}
