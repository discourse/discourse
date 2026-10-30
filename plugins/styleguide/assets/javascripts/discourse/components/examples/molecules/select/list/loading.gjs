import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { delay, TIMEZONES } from "../../../../../lib/select-fixtures.js";

export default class ListLoadingExample extends Component {
  @tracked value = [];

  @action
  async load(filter, { signal }) {
    await delay(signal, 1500);
    return TIMEZONES.filter((zone) =>
      zone.name.toLowerCase().includes(filter.toLowerCase())
    );
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      class="select-examples__tag-list"
      @ariaLabel={{i18n "styleguide.sections.select.list_timezones_label"}}
      @identifier="sg-list-loading"
      @load={{this.load}}
      @onChange={{this.onChange}}
      @searchPlaceholder={{i18n
        "styleguide.sections.select.placeholders.search_cities"
      }}
      @value={{this.value}}
      @valueItems={{TIMEZONES}}
      @virtualized={{false}}
    />
  </template>
}
