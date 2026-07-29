import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class MaximumSelectExample extends Component {
  @tracked value = ["en", "es", "pt-BR"];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-maximum"
      @items={{LOCALES}}
      @multiple={{true}}
      @maximum={{3}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.multi_placeholder"}}
    />
  </template>
}
