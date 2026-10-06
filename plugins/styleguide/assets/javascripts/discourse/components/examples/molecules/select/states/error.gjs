import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { createRetryingLocaleApi } from "../../../../../lib/select-fixtures";

export default class ErrorSelectExample extends Component {
  @tracked value = null;

  api = createRetryingLocaleApi();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-error"
      @load={{this.api.search}}
      @onChange={{this.onChange}}
      @onClose={{this.api.reset}}
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
      @resolveValue={{this.api.find}}
      @value={{this.value}}
      @variant="button"
    />
  </template>
}
