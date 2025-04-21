import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { and, not } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";

export default class SchemaThemeSettingTypeString extends Component {
  @tracked touched = false;
  @tracked value = this.args.value || "";
  minLength = this.args.spec.validations?.min_length;
  maxLength = this.args.spec.validations?.max_length;
  required = this.args.spec.required;

  @action
  onInput(event) {
    this.touched = true;
    const newValue = event.currentTarget.value;
    this.args.onChange(newValue);
    this.value = newValue;
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    const valueLength = this.value.length;

    if (valueLength === 0) {
      if (this.required) {
        return i18n("admin.customize.theme.schema.fields.required");
      } else {
        return;
      }
    }

    if (this.minLength && valueLength < this.minLength) {
      return i18n("admin.customize.theme.schema.fields.string.too_short", {
        count: this.minLength,
      });
    }
  }

  <template>
    <Input
      class="--string"
      @value={{this.value}}
      {{on "input" this.onInput}}
      required={{this.required}}
      minLength={{this.minLength}}
      maxLength={{this.maxLength}}
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

      {{#if this.maxLength}}
        <div
          class={{concatClass
            "schema-field__input-count"
            (if this.validationErrorMessage " --error")
          }}
        >
          {{this.value.length}}/{{this.maxLength}}
        </div>
      {{/if}}
    </div>
  </template>
}
