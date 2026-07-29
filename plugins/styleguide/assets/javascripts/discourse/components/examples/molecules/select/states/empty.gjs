import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { delay } from "../../../../../lib/select-fixtures";

export default class EmptySelectExample extends Component {
  @tracked value = null;

  @action
  async load(_filter, { signal }) {
    await delay(signal);
    return [];
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-empty"
      @load={{this.load}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      @noResultsLabel={{i18n "styleguide.sections.select.empty_label"}}
    />
  </template>
}
