import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { delay, TAGS } from "../../../../../lib/select-fixtures.js";

export default class ListLoadingExample extends Component {
  @tracked value = [];

  tags = TAGS;

  @action
  async load(filter, { signal }) {
    await delay(signal, 1500);
    return TAGS.filter((tag) => tag.label.includes(filter.toLowerCase()));
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      class="select-examples__tag-list"
      @identifier="sg-list-loading"
      @label={{i18n "styleguide.sections.select.list_tags_label"}}
      @labelField="label"
      @load={{this.load}}
      @onChange={{this.onChange}}
      @searchPlaceholder={{i18n "styleguide.sections.select.list_search"}}
      @value={{this.value}}
      @valueField="slug"
      @valueItems={{this.tags}}
      @virtualized={{false}}
    />
  </template>
}
