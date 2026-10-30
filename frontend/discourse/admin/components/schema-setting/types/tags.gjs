import { action } from "@ember/object";
import { service } from "@ember/service";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";

export default class SchemaSettingTypeTags extends SchemaSettingTypeModels {
  @service siteSettings;

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

  @action
  onNamesInput(names) {
    this.value = names;
    this.args.onChange(names);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup) }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectTag
        class={{if this.validationErrorMessage "--invalid"}}
        @allowCreate={{false}}
        @emit="names"
        @ignoreRestrictions={{@spec.every_tag}}
        @maximum={{this.max}}
        @multiple={{true}}
        @onChange={{this.onNamesInput}}
        @value={{this.value}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup) }}
      <TagChooser
        class={{if this.validationErrorMessage "--invalid"}}
        @everyTag={{@spec.every_tag}}
        @onChange={{this.onInput}}
        @options={{this.tagChooserOption}}
        @tags={{this.value}}
      />
    {{/if}}

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
