import { and, not } from "truth-helpers";
import FieldInputDescription from "admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "admin/components/schema-setting/types/models";
import TagChooser from "select-kit/components/tag-chooser";

export default class SchemaSettingTypeTags extends SchemaSettingTypeModels {
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
