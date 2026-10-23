import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import { i18n } from "discourse-i18n";
import { pagedTopicApi } from "../../../../../lib/select-fixtures.js";

export default class ListPaginatedExample extends Component {
  @tracked value = [];

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelectList
      @identifier="sg-list-paginated"
      @label={{i18n "styleguide.sections.select.list_topics_label"}}
      @load={{pagedTopicApi.search}}
      @onChange={{this.onChange}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      @resolveValues={{pagedTopicApi.findMany}}
      @value={{this.value}}
    />
  </template>
}
