import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { notificationLevels } from "../../../../../lib/select-fixtures";

export default class ValueIconSelectExample extends Component {
  @tracked value = "tracking";

  get items() {
    return notificationLevels();
  }

  get icon() {
    return this.items.find((item) => item.level === this.value)?.icon ?? "bell";
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-icon-follows"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @valueField="level"
      @labelField="title"
      @icon={{this.icon}}
      @variant="static"
    >
      <:item as |level|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon level.icon}}
          <span class="select-examples__primary">{{level.title}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
