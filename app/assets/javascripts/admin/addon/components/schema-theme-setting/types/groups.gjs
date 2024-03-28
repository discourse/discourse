import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import I18n from "discourse-i18n";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import GroupChooser from "select-kit/components/group-chooser";

export default class SchemaThemeSettingTypeGroups extends Component {
  @service site;
  @tracked touched = false;
  @tracked value = this.args.value;

  required = this.args.spec.required;
  min = this.args.spec.validations?.min;
  max = this.args.spec.validations?.max;

  @action
  onInput(newVal) {
    this.touched = true;
    this.value = newVal;
    this.args.onChange(newVal);
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (
      (this.min && this.value.length < this.min) ||
      (this.required && (!this.value || this.value.length === 0))
    ) {
      return I18n.t("admin.customize.theme.schema.fields.groups.at_least", {
        count: this.min || 1,
      });
    }
  }

  get groupChooserOptions() {
    return {
      clearable: !this.required,
      filterable: true,
      maximum: this.max,
    };
  }

  <template>
    <GroupChooser
      @content={{this.site.groups}}
      @value={{this.value}}
      @onChange={{this.onInput}}
      @options={{this.groupChooserOptions}}
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
