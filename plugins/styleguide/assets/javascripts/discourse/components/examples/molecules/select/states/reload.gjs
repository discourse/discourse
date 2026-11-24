import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  fastTopicApi,
  pagedTopicApi,
} from "../../../../../lib/select-fixtures.js";

export default class ReloadSelectExample extends Component {
  @tracked value = null;

  api = this.args.speed === "fast" ? fastTopicApi : pagedTopicApi;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier={{@identifier}}
      @load={{this.api.search}}
      @onChange={{this.onChange}}
      @resolveValue={{this.api.find}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.search_topics"
        )
      }}
      @value={{this.value}}
    />
  </template>
}
