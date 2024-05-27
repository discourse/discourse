import { and, not } from "truth-helpers";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import SchemaThemeSettingTypeModels from "admin/components/schema-theme-setting/types/models";
import TagChooser from "select-kit/components/tag-chooser";

export default class SchemaThemeSettingTypeTags extends SchemaThemeSettingTypeModels {
  type = "tags";

  get tagChooserOption() {
    return {
      allowAny: false,
      maximum: this.max,
    };
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
