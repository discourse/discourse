import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { and, not } from "truth-helpers";
import I18n from "discourse-i18n";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import TagChooser from "select-kit/components/tag-chooser";

export default class SchemaThemeSettingTypeTags extends Component {
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

  get tagChooserOption() {
    return {
      allowAny: false,
      maximum: this.max,
    };
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (
      (this.min && this.value.length < this.min) ||
      (this.required && (!this.value || this.value.length === 0))
    ) {
      return I18n.t("admin.customize.theme.schema.fields.tags.at_least_tag", {
        count: this.min,
      });
    }
  }

  <template>
    <TagChooser
      @tags={{this.value}}
      @onChange={{this.onInput}}
      @options={{this.tagChooserOption}}
      class={{if this.validationErrorMessage "--invalid"}}
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
