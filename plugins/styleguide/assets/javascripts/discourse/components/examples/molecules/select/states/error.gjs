import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { createRetryingGroupApi } from "../../../../../lib/select-fixtures.js";

export default class ErrorSelectExample extends Component {
  @tracked value = null;

  api = createRetryingGroupApi();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-error"
      @labelField="fullName"
      @load={{this.api.search}}
      @onChange={{this.onChange}}
      @onClose={{this.api.reset}}
      @placeholder={{i18n
        "styleguide.sections.select.placeholders.choose_group"
      }}
      @resolveValue={{this.api.find}}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
