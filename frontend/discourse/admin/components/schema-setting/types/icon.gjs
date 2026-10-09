/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import { and, not } from "discourse/truth-helpers";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import { i18n } from "discourse-i18n";

export default class SchemaSettingTypeIcon extends Component {
  @tracked touched = false;
  @tracked value = this.args.value;
  required = this.args.spec.required;

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (!this.value && this.required) {
      return i18n("admin.customize.schema.fields.required");
    }
  }

  @action
  onChange(newValue) {
    this.touched = true;
    this.value = newValue;
    this.args.onChange(newValue);
  }

  <template>
    <DIconGridPicker
      @allowClear={{not this.required}}
      @onChange={{this.onChange}}
      @showCaret={{true}}
      @showSelectedName={{true}}
      @value={{this.value}}
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
