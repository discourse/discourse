import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { activityFilterApi } from "../../../../../lib/select-fixtures.js";

export default class AsyncButtonSelectExample extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-async-button"
      @load={{activityFilterApi.search}}
      @onChange={{this.onChange}}
      @resolveValue={{activityFilterApi.find}}
      @texts={{hash
        placeholder=(i18n
          "styleguide.sections.select.placeholders.filter_activity"
        )
      }}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
