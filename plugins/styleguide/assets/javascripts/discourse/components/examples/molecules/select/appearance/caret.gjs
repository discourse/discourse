import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class CaretSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-caret"
      @items={{LOCALES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @caretIcon={{hash open="caret-up" closed="caret-down"}}
      @variant="static"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
