import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, not } from "truth-helpers";
import I18n from "discourse-i18n";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";

export default class SchemaThemeSettingTypeInteger extends Component {
  @tracked touched = false;
  @tracked value = this.args.value;
  min = this.args.spec.validations?.min;
  max = this.args.spec.validations?.max;
  required = this.args.spec.required;

  @action
  onInput(event) {
    this.touched = true;
    let newValue = parseInt(event.currentTarget.value, 10);

    if (isNaN(newValue)) {
      newValue = null;
    }

    this.value = newValue;
    this.args.onChange(newValue);
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (!this.value) {
      if (this.required) {
        return I18n.t("admin.customize.theme.schema.fields.required");
      } else {
        return;
      }
    }

    if (this.min && this.value < this.min) {
      return I18n.t("admin.customize.theme.schema.fields.number.too_small", {
        count: this.min,
      });
    }

    if (this.max && this.value > this.max) {
      return I18n.t("admin.customize.theme.schema.fields.number.too_large", {
        count: this.max,
      });
    }
  }

  <template>
    <Input
      @value={{this.value}}
      {{on "input" this.onInput}}
      @type="number"
      inputmode="numeric"
      pattern="[0-9]*"
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
