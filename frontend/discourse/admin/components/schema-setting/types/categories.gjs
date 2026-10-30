import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import FieldInputDescription from "discourse/admin/components/schema-setting/field-input-description";
import SchemaSettingTypeModels from "discourse/admin/components/schema-setting/types/models";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";

export default class SchemaSettingTypeCategories extends SchemaSettingTypeModels {
  @service siteSettings;

  @tracked
  value =
    this.args.value
      ?.map((categoryId) => {
        return (
          this.categoriesMetadata[categoryId] || Category.findById(categoryId)
        );
      })
      .filter(Boolean) || [];

  type = "categories";

  get categoriesMetadata() {
    this.args.setting.metadata ||= {};
    this.args.setting.metadata.categories ||= {};
    return this.args.setting.metadata.categories;
  }

  onChange(categories) {
    return categories.map((category) => {
      this.categoriesMetadata[category.id] ||= category;
      return category.id;
    });
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectCategory
        class="category-selector"
        @ariaLabel={{@label}}
        @maximum={{this.max}}
        @multiple={{true}}
        @onChange={{this.onInput}}
        @uncategorized={{false}}
        @value={{this.value}}
      />
    {{else}}
      <CategorySelector
        @categories={{this.value}}
        @onChange={{this.onInput}}
        @options={{hash allowUncategorized=false maximum=this.max}}
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
