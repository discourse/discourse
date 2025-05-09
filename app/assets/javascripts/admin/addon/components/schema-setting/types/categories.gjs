import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { and, not } from "truth-helpers";
import FieldInputDescription from "admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "admin/components/schema-setting/types/models";
import CategorySelector from "select-kit/components/category-selector";

export default class SchemaSettingTypeCategories extends SchemaSettingTypeModels {
  @tracked
  value =
    this.args.value?.map((categoryId) => {
      return this.args.setting.metadata.categories[categoryId];
    }) || [];

  type = "categories";

  onChange(categories) {
    return categories.map((category) => {
      this.args.setting.metadata.categories[category.id] ||= category;
      return category.id;
    });
  }

  <template>
    <CategorySelector
      @categories={{this.value}}
      @onChange={{this.onInput}}
      @options={{hash allowUncategorized=false maximum=this.max}}
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
