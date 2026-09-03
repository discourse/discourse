import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { activityFilterApi } from "../../../../../lib/select-fixtures";

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
      @resolveValue={{activityFilterApi.find}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    />
  </template>
}
