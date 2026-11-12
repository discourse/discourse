import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { notificationLevels } from "../../../../../lib/select-fixtures.js";

export default class ValueIconSelectExample extends Component {
  @tracked value = "tracking";

  get items() {
    return notificationLevels();
  }

  get icon() {
    return (
      this.items.find(({ record }) => record.level === this.value)?.record
        .icon ?? "bell"
    );
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @icon={{this.icon}}
      @identifier="sg-icon-follows"
      @labelField="title"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
      @valueField="level"
      @variant="static"
    >
      <:option as |level|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon level.icon}}
          <span class="select-examples__primary">{{level.title}}</span>
        </span>
      </:option>
    </DSelect>
  </template>
}
