import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { FOUR_OPTIONS } from "../../../../../lib/select-fixtures";

export default class MultipleSelectExample extends Component {
  @tracked value = [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-multi"
      @items={{FOUR_OPTIONS}}
      @multiple={{true}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
    />
  </template>
}
