import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class DateTimeField extends BaseField {
  <template>
    <section class="field date-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          <div class="controls-row">
            <Input
              disabled={{@field.isDisabled}}
              @type="datetime-local"
              @value={{readonly this.localTime}}
              {{on "input" this.convertToUniversalTime}}
            />

            {{#if @field.metadata.value}}
              <DButton
                @action={{this.reset}}
                @disabled={{@field.isDisabled}}
                @icon="trash-can"
              />
            {{/if}}
          </div>

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  get localTime() {
    return (
      this.args.field.metadata.value &&
      moment(this.args.field.metadata.value)
        .local()
        .format(moment.HTML5_FMT.DATETIME_LOCAL)
    );
  }

  @action
  convertToUniversalTime(event) {
    const date = event.target.value;
    if (!date) {
      return;
    }

    this.mutValue(moment(date).utc().format());
  }

  @action
  reset() {
    this.mutValue(null);
  }
}
