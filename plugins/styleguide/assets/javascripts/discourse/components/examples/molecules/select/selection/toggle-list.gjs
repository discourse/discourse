import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class ToggleListSelectExample extends Component {
  @tracked value = ["en", "pt-BR"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-toggle"
      @items={{LOCALES}}
      @label={{i18n "styleguide.sections.select.toggle_label"}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
