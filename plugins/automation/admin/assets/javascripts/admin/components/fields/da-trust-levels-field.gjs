import { action } from "@ember/object";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import MultiSelect from "select-kit/components/multi-select";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class TrustLevelsField extends BaseField {
  @service site;

  @action
  onChangeTrustLevels(value) {
    if (isBlank(value)) {
      value = undefined;
    }

    this.mutValue(value);
  }

  <template>
    <section class="field category-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <MultiSelect
            @value={{@field.metadata.value}}
            @content={{this.site.trustLevels}}
            @onChange={{this.onChangeTrustLevels}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
