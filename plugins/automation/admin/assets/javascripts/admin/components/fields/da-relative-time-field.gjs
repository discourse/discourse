import RelativeTimePicker from "discourse/components/relative-time-picker";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class RelativeTimeField extends BaseField {
  <template>
    <section class="field text-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <div class="field-wrapper">
            <RelativeTimePicker
              @durationMinutes={{@field.metadata.value}}
              @onChange={{this.mutValue}}
            />

            <DAFieldDescription @description={{@description}} />
          </div>
        </div>
      </div>
    </section>
  </template>
}
