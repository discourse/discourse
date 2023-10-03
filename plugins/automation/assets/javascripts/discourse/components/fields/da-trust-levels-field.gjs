import BaseField from "./da-base-field";
import MultiSelect from "select-kit/components/multi-select";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import { inject as service } from "@ember/service";

export default class TrustLevelsField extends BaseField {
  <template>
    <section class="field category-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <MultiSelect
            @value={{@field.metadata.value}}
            @content={{this.site.trustLevels}}
            @onChange={{this.mutValue}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @service site;
}
