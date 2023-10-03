import BaseField from "./da-base-field";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import { Input } from "@ember/component";
import PlaceholdersList from "../placeholders-list";
import { action } from "@ember/object";
import { on } from "@ember/modifier";

export default class TextField extends BaseField {
  <template>
    <section class="field text-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <div class="field-wrapper">
            <Input
              @value={{@field.metadata.value}}
              disabled={{@field.isDisabled}}
              {{on "input" this.mutText}}
              name={{@field.name}}
            />

            <DAFieldDescription @description={{@description}} />

            {{#if this.displayPlaceholders}}
              <PlaceholdersList
                @currentValue={{@field.metadata.value}}
                @placeholders={{@placeholders}}
                @onCopy={{this.mutValue}}
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
