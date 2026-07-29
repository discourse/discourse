import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { LOCALES } from "../../../../../lib/select-fixtures";

export default class PlacementSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-placement"
      @items={{LOCALES}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @placement="top"
      @offset={{16}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
