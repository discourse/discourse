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
      @ariaLabel={{i18n "styleguide.sections.select.list_topics_label"}}
      @identifier="sg-list-paginated"
      @load={{pagedTopicApi.search}}
      @onChange={{this.onChange}}
      @resolveValues={{pagedTopicApi.findMany}}
      @searchPlaceholder={{i18n
        "styleguide.sections.select.placeholders.search_topics"
      }}
      @value={{this.value}}
    />
  </template>
}
