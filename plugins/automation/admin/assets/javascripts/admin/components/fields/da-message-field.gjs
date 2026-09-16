import { action } from "@ember/object";
import DTextarea from "discourse/ui-kit/d-textarea";
import PlaceholdersList from "../placeholders-list";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class MessageField extends BaseField {
  <template>
    <section class="field message-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <div class="field-wrapper">
            <DTextarea
              @disabled={{@field.isDisabled}}
              @input={{this.updateValue}}
              @value={{@field.metadata.value}}
            />

            <DAFieldDescription @description={{@description}} />

            {{#if this.displayPlaceholders}}
              <PlaceholdersList
                @currentValue={{@field.metadata.value}}
                @onCopy={{this.mutValue}}
                @placeholders={{@placeholders}}
              />
            {{/if}}
          </div>
        </div>
      </div>
    </section>
  </template>

  @action
  updateValue(event) {
    this.mutValue(event.target.value);
  }
}
