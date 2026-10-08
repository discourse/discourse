import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class ClearableMultipleSelectExample extends Component {
  @tracked value = ["en", "es"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @clearable={{true}}
      @identifier="sg-clearable-multi"
      @items={{LOCALES}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
      @value={{this.value}}
    />
  </template>
}
