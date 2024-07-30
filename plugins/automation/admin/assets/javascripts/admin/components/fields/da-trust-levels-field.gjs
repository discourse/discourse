import { service } from "@ember/service";
import MultiSelect from "select-kit/components/multi-select";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class TrustLevelsField extends BaseField {
  @service site;

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
}
