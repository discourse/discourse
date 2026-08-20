import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TIMEZONES } from "../../../../../lib/select-fixtures";

export default class DividerSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  // Splitter placement relies on TIMEZONES being sorted by offset; groups follow first appearance.
  <template>
    <DSelect
      @identifier="sg-divided"
      @items={{TIMEZONES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @groupBy="offsetMinutes"
      @placeholder={{i18n
        "styleguide.sections.select.content.divided_placeholder"
      }}
    />
  </template>
}
