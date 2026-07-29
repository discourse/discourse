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
      @multiple={{true}}
      @variant="button"
      @value={{this.value}}
      @onChange={{this.onChange}}
      @label={{i18n "styleguide.sections.select.toggle_label"}}
      @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
    />
  </template>
}
