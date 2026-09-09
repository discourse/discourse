import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PlaceholdersList from "../placeholders-list";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class TextField extends BaseField {
  <template>
    <section class="field text-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <div class="field-wrapper">
            <Input
              disabled={{@field.isDisabled}}
              name={{@field.name}}
              @value={{@field.metadata.value}}
              {{on "input" this.mutText}}
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
  mutText(event) {
    this.mutValue(event.target.value);
  }
}
