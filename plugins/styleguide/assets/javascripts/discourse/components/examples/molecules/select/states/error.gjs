import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { delay, LOCALES } from "../../../../../lib/select-fixtures";

export default class ErrorSelectExample extends Component {
  @tracked value = null;

  requestCount = 0;

  @action
  async load(filter, { signal }) {
    await delay(signal);
    this.requestCount++;

    if (this.requestCount === 1) {
      throw new Error(i18n("styleguide.sections.select.request_error"));
    }

    return LOCALES.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  reset() {
    this.requestCount = 0;
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
      @identifier="sg-error"
      @load={{this.load}}
      @onClose={{this.reset}}
      @resolveValue={{this.resolveValue}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
