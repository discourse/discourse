import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  ASYNC_BUTTON_DELAY,
  delay,
  LOCALES,
} from "../../../../../lib/select-fixtures";

export default class MinimumCharactersSelectExample extends Component {
  @tracked value = null;

  @action
  async load(filter, { signal }) {
    await delay(signal, ASYNC_BUTTON_DELAY);
    return LOCALES.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  resolveValue(value) {
    return LOCALES.find((item) => item.id === value);
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-min-chars"
      @load={{this.load}}
      @resolveValue={{this.resolveValue}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @minChars={{3}}
      @clearable={{true}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
