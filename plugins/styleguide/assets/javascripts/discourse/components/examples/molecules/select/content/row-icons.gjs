import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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
      @identifier="sg-row-icons"
      @labelField="title"
      @onChange={{this.onChange}}
      @options={{this.items}}
      @value={{this.value}}
    >
      <:option as |visibility|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dIcon visibility.icon}}
          <span class="select-examples__primary">{{visibility.title}}</span>
        </span>
      </:option>
    </DSelect>
  </template>
}
