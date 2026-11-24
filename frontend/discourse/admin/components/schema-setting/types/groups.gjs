import { service } from "@ember/service";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";

export default class SchemaSettingTypeGroups extends SchemaSettingTypeModels {
  @service site;
  @service siteSettings;

  type = "groups";

  get groupChoices() {
    const disallowed = (this.args.spec.disallowed_groups || "")
      .split("|")
      .filter(Boolean);

    return (this.site.groups || []).filter(
      (group) => !disallowed.includes(group.id.toString())
    );
  }

  get disallowedGroupIds() {
    return (this.args.spec.disallowed_groups || "")
      .split("|")
      .filter(Boolean)
      .map(Number);
  }

  get groupChooserOptions() {
    return {
      clearable: !this.required,
      filterable: true,
      maximum: this.max,
    };
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup) }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectGroup
        @clearable={{not this.required}}
        @exclude={{this.disallowedGroupIds}}
        @maximum={{this.max}}
        @multiple={{true}}
        @onChange={{this.onInput}}
        @value={{this.value}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup) }}
      <GroupChooser
        @content={{this.groupChoices}}
        @onChange={{this.onInput}}
        @options={{this.groupChooserOptions}}
        @value={{this.value}}
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
