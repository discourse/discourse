import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, not } from "truth-helpers";
import { i18n } from "discourse-i18n";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";

export default class SchemaThemeSettingNumberField extends Component {
  @tracked touched = false;
  @tracked value = this.args.value;
  min = this.args.spec.validations?.min;
  max = this.args.spec.validations?.max;
  required = this.args.spec.required;

  @action
  onInput(event) {
    this.touched = true;
    let inputValue = event.currentTarget.value;

    if (isNaN(inputValue)) {
      this.value = null;
    } else {
      this.value = this.parseValue(inputValue);
    }

    this.args.onChange(this.value);
  }

  /**
   * @param {string} value - The value of the input field to parse into a number
   * @returns {number}
   */
  parseFunc() {
    throw "Not implemented";
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (!this.value) {
      if (this.required) {
        return i18n("admin.customize.theme.schema.fields.required");
      } else {
        return;
      }
    }

    if (this.min && this.value < this.min) {
      return i18n("admin.customize.theme.schema.fields.number.too_small", {
        count: this.min,
      });
    }

    if (this.max && this.value > this.max) {
      return i18n("admin.customize.theme.schema.fields.number.too_large", {
        count: this.max,
      });
    }
  }

  <template>
    <Input
      @value={{this.value}}
      {{on "input" this.onInput}}
      @type="number"
      inputmode={{this.inputmode}}
      pattern={{this.pattern}}
      step={{this.step}}
      max={{this.max}}
      min={{this.min}}
      required={{this.required}}
    />

    <div class="schema-field__input-supporting-text">
      {{#if (and @description (not this.validationErrorMessage))}}
        <FieldInputDescription @description={{@description}} />
      {{/if}}

      {{#if this.validationErrorMessage}}
        <div class="schema-field__input-error">
          {{this.validationErrorMessage}}
        </div>
      {{/if}}
    </div>
  </template>
}
