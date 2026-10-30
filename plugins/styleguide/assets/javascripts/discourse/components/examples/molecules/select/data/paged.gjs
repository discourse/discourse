import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { pagedTopicApi } from "../../../../../lib/select-fixtures.js";

export default class PagedSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-paged"
      @load={{pagedTopicApi.search}}
      @onChange={{this.onChange}}
      @resolveValue={{pagedTopicApi.find}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.search_topics"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
