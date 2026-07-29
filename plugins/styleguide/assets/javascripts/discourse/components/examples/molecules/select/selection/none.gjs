import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class NoneSelectExample extends Component {
  @tracked value = "es";

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-none"
      @items={{LOCALES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @noneLabel={{i18n "styleguide.sections.select.none_label"}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
