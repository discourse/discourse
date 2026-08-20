import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { createRetryingPeopleApi } from "../../../../../lib/select-fixtures";

export default class CustomErrorSelectExample extends Component {
  @tracked value = null;

  api = createRetryingPeopleApi();

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-content-error"
      @load={{this.api.search}}
      @onClose={{this.api.reset}}
      @resolveValue={{this.api.find}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="button"
      @labelField="name"
      @placeholder={{i18n "styleguide.sections.select.placeholder"}}
    >
      <:error as |error retry|>
        <span class="select-examples__error-message">
          {{dIcon "triangle-exclamation"}}
          {{error.message}}
        </span>
        <DButton
          class="d-combobox__retry btn-flat"
          @action={{retry}}
          @label="styleguide.sections.select.content.error_retry"
        />
      </:error>
    </DSelect>
  </template>
}
