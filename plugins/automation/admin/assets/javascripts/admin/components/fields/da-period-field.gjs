import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class PeriodField extends BaseField {
  @tracked interval = 1;
  @tracked frequency = null;

  constructor() {
    super(...arguments);

    next(() => {
      if (!this.args.field.metadata.value) {
        this.args.field.metadata.value = new TrackedObject({
          interval: 1,
          frequency: null,
        });
      }

      this.interval = this.args.field.metadata.value.interval;
      this.frequency = this.args.field.metadata.value.frequency;
    });
  }

  get recurringLabel() {
    return i18n("discourse_automation.triggerables.recurring.every");
  }

  get replacedContent() {
    return (this.args.field?.extra?.content || []).map((r) => {
      return {
        id: r.id,
        name: i18n(r.name),
      };
    });
  }

  @action
  mutInterval(event) {
    this.args.field.metadata.value.interval = event.target.value;
  }

  @action
  mutFrequency(value) {
    this.args.field.metadata.value.frequency = value;
    this.frequency = value;
  }

  <template>
    <div class="field period-field control-group">
      <DAFieldLabel @label={{@label}} @field={{@field}} />

      <div class="controls">
        {{this.recurringLabel}}

        <Input
          @type="number"
          defaultValue="1"
          @value={{this.interval}}
          disabled={{@field.isDisabled}}
          required={{@field.isRequired}}
          {{on "input" this.mutInterval}}
        />

        <ComboBox
          @value={{this.frequency}}
          @content={{this.replacedContent}}
          @onChange={{this.mutFrequency}}
          @options={{hash allowAny=false disabled=@field.isDisabled}}
          @required={{@field.isRequired}}
        />

        <DAFieldDescription @description={{@description}} />
      </div>
    </div>
  </template>
}
