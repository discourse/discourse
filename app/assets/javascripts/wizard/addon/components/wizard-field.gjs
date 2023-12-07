import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import fields from "./fields";

export default class WizardFieldComponent extends Component {
  get field() {
    return this.args.field;
  }

  get classes() {
    let classes = ["wizard-container__field"];

    let { type, id, invalid, disabled } = this.field;

    classes.push(`${dasherize(type)}-field`);
    classes.push(`${dasherize(type)}-${dasherize(id)}`);

    if (invalid) {
      classes.push("invalid");
    }

    if (disabled) {
      classes.push("disabled");
    }

    return classes.join(" ");
  }

  get fieldClass() {
    return `field-${dasherize(this.field.id)} wizard-focusable`;
  }

  get component() {
    let { type } = this.field;
    assert(`"${type}" is not a valid wizard field type`, type in fields);
    return fields[type];
  }

  <template>
    <div class={{this.classes}}>
      {{#if @field.label}}
        <label for={{@field.id}}>
          <span class="wizard-container__label">
            {{@field.label}}
          </span>

          {{#if @field.required}}
            <span class="wizard-container__label required">*</span>
          {{/if}}

          {{#if @field.description}}
            <div class="wizard-container__description">
              {{htmlSafe @field.description}}
            </div>
          {{/if}}
        </label>
      {{/if}}

      <div class="wizard-container__input">
        <this.component
          @wizard={{@wizard}}
          @step={{@step}}
          @field={{@field}}
          @fieldClass={{this.fieldClass}}
        />
      </div>

      {{#if @field.errorDescription}}
        <div class="wizard-container__description error">
          {{htmlSafe this.field.errorDescription}}
        </div>
      {{/if}}

      {{#if @field.extraDescription}}
        <div class="wizard-container__description extra">
          {{htmlSafe this.field.extraDescription}}
        </div>
      {{/if}}
    </div>
  </template>
}
