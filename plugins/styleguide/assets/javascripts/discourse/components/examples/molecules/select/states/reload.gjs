import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { delay, PAGE_SIZE, topics } from "../../../../../lib/select-fixtures";

export default class ReloadSelectExample extends Component {
  @tracked value = null;

  items = topics();

  @action
  async load(filter, { signal, offset = 0, limit = PAGE_SIZE }) {
    await delay(signal, this.args.duration);
    const matches = this.items.filter((item) =>
      item.name.toLowerCase().includes(filter.toLowerCase())
    );
    return {
      items: matches.slice(offset, offset + limit),
      total: matches.length,
    };
  }

  @action
  resolveValue(value) {
    return this.items.find((item) => item.id === value);
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier={{@identifier}}
      @load={{this.load}}
      @resolveValue={{this.resolveValue}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
