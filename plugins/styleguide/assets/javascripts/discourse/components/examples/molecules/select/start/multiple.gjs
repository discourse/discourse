import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { PEOPLE } from "../../../../../lib/select-fixtures.js";

export default class MultipleSelectExample extends Component {
  @tracked value = [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-multi"
      @items={{PEOPLE}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholders.add_people"}}
      @value={{this.value}}
    />
  </template>
}
