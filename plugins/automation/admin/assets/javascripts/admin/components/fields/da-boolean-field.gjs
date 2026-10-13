import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class BooleanField extends BaseField {
  <template>
    <section class="field boolean-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <Input
            disabled={{@field.isDisabled}}
            @checked={{@field.metadata.value}}
            @type="checkbox"
            {{on "input" this.onInput}}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @action
  onInput(event) {
    this.mutValue(event.target.checked);
  }
}
