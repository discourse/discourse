import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { notificationLevels } from "../../../../../lib/select-fixtures";

export default class RowIconsSelectExample extends Component {
  @tracked value = "tracking";

  items = notificationLevels();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-row-icons"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @valueField="level"
      @labelField="title"
    >
      <:item as |level|>
        <span class="select-examples__row">
          {{dIcon level.icon}}
          <span class="select-examples__details">
            <span class="select-examples__primary">{{level.title}}</span>
            <span class="select-examples__secondary">
              {{level.description}}
            </span>
          </span>
        </span>
      </:item>
    </DSelect>
  </template>
}
