import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class DisabledSelectExample extends Component {
  @tracked value = "en";

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @disabled={{true}}
      @identifier="sg-disabled"
      @items={{LOCALES}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
