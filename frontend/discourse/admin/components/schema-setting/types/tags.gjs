import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { and, not } from "discourse/truth-helpers";

export default class SchemaSettingTypeTags extends SchemaSettingTypeModels {
  type = "tags";

  get tagChooserOption() {
    return {
      allowAny: false,
      maximum: this.max,
    };
  }

  onChange(tags) {
    return tags.map((tag) => tag.name);
  }

  <template>
    <TagChooser
      class={{if this.validationErrorMessage "--invalid"}}
      @everyTag={{@spec.every_tag}}
      @onChange={{this.onInput}}
      @options={{this.tagChooserOption}}
      @tags={{this.value}}
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
