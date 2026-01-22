import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Textarea } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import icon from "discourse/helpers/d-icon";

export default class FormTemplateFieldTextarea extends Component {
  @service appEvents;

  @tracked value = this.args.value || "";

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:replace-text", this, this.handleReplaceText);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("composer:replace-text", this, this.handleReplaceText);
  }

  @action
  handleReplaceText(oldVal, newVal) {
    if (this.value?.includes(oldVal)) {
      const escapedOldVal = oldVal.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const regex = new RegExp(escapedOldVal, "g");
      this.value = this.value.replace(regex, newVal ?? "");

      schedule("afterRender", () => {
        this.args.onChange?.();
      });
    }
  }

  @action
  onInput(event) {
    this.value = event.target.value;
    this.args.onChange?.(event);
  }

  <template>
    <div class="control-group form-template-field" data-field-type="textarea">
      {{#if @attributes.label}}
        <label class="form-template-field__label">
          {{@attributes.label}}
          {{#if @validations.required}}
            {{icon "asterisk" class="form-template-field__required-indicator"}}
          {{/if}}
        </label>
      {{/if}}

      {{#if @attributes.description}}
        <span class="form-template-field__description">
          {{htmlSafe @attributes.description}}
        </span>
      {{/if}}

      <Textarea
        name={{@id}}
        @value={{this.value}}
        class="form-template-field__textarea"
        placeholder={{@attributes.placeholder}}
        pattern={{@validations.pattern}}
        minlength={{@validations.minimum}}
        maxlength={{@validations.maximum}}
        required={{if @validations.required "required" ""}}
        {{on "input" this.onInput}}
      />
    </div>
  </template>
}
