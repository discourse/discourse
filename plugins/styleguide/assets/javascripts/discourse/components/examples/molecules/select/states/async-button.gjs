import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  ASYNC_BUTTON_DELAY,
  delay,
  FOUR_OPTIONS,
} from "../../../../../lib/select-fixtures";

export default class AsyncButtonSelectExample extends Component {
  @tracked value = null;

  @action
  async load(filter, { signal }) {
    await delay(signal, ASYNC_BUTTON_DELAY);
    return FOUR_OPTIONS.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  resolveValue(value) {
    return FOUR_OPTIONS.find((item) => item.id === value);
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-async-button"
      @load={{this.load}}
      @resolveValue={{this.resolveValue}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
