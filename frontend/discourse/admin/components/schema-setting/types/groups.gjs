import { service } from "@ember/service";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { and, not } from "discourse/truth-helpers";

export default class SchemaSettingTypeGroups extends SchemaSettingTypeModels {
  @service site;

  type = "groups";

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
