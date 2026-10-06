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
      @caretIcon={{hash open="caret-up" closed="caret-down"}}
      @identifier="sg-caret"
      @items={{LOCALES}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      @value={{this.value}}
      @variant="static"
    />
  </template>
}
