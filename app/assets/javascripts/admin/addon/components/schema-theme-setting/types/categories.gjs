import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { and, not } from "truth-helpers";
import I18n from "discourse-i18n";
import FieldInputDescription from "admin/components/schema-theme-setting/field-input-description";
import CategorySelector from "select-kit/components/category-selector";

export default class SchemaThemeSettingTypeCategories extends Component {
  @tracked touched = false;

  @tracked
  value =
    this.args.value?.map((categoryId) => {
      return this.args.setting.metadata.categories[categoryId];
    }) || [];

  required = this.args.spec.required;
  min = this.args.spec.validations?.min;
  max = this.args.spec.validations?.max;

  @action
  onInput(categories) {
    this.touched = true;
    this.value = categories;
    this.args.onChange(categories.map((category) => category.id));
  }

  get validationErrorMessage() {
    if (!this.touched) {
      return;
    }

    if (
      (this.min && this.value.length < this.min) ||
      (this.required && (!this.value || this.value.length === 0))
    ) {
      return I18n.t("admin.customize.theme.schema.fields.categories.at_least", {
        count: this.min || 1,
      });
    }
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
