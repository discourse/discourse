import { cached } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { resolveCategories } from "discourse/lib/category-source";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import CategorySelector from "discourse/select-kit/components/category-selector";
import { decodeCategoryText } from "discourse/ui-kit/select/recipes/categories/category-renderers";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

/** Stores a category id or, with `@multiple`, an array of category ids. */
export default class FKControlCategoryChooser extends FKBaseControl {
  static controlType = "category-chooser";

  @service site;
  @service siteSettings;

  /** Resolves records for the legacy multiple picker without writing form data. */
  @cached
  get categories() {
    const ids = this.args.field.value ?? [];
    return new TrackedAsyncData(
      this.site.lazy_load_categories
        ? resolveCategories(ids)
        : Category.findByIds(ids)
    );
  }

  get multiple() {
    return this.args.multiple ?? false;
  }

  get placeholder() {
    return this.args.placeholder
      ? decodeCategoryText(i18n(this.args.placeholder))
      : undefined;
  }

  @action
  handleChange(value) {
    if (this.multiple) {
      this.args.field.set((value ?? []).map(Number));
      return;
    }
    this.args.field.set(value == null ? null : Number(value));
  }

  @action
  handleCategoriesChange(categories) {
    this.handleChange(categories.map((category) => category.id));
  }

  <template>
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectCategory
        class="form-kit__control-category-chooser"
        ...attributes
        @clearable={{true}}
        @describedBy={{@field.describedBy}}
        @disabled={{@field.disabled}}
        @emit="ids"
        @exclude={{@exclude}}
        @id={{@field.id}}
        @invalid={{if @field.error true false}}
        @label={{@field.title}}
        @maximum={{@maximum}}
        @multiple={{this.multiple}}
        @onChange={{this.handleChange}}
        @permission={{@permission}}
        @placeholder={{this.placeholder}}
        @subcategories={{@subcategories}}
        @uncategorized={{@uncategorized}}
        @value={{readonly @field.value}}
      />
    {{else if this.multiple}}
      <CategorySelector
        class="form-kit__control-category-chooser"
        ...attributes
        @categories={{if
          this.categories.isResolved
          this.categories.value
          (array)
        }}
        @onChange={{this.handleCategoriesChange}}
        @options={{hash
          disabled=(or @field.disabled (not this.categories.isResolved))
          maximum=@maximum
          none=@placeholder
        }}
      />
    {{else}}
      <CategoryChooser
        class="form-kit__control-category-chooser"
        ...attributes
        @onChange={{this.handleChange}}
        @options={{hash
          disabled=@field.disabled
          none=@placeholder
          clearable=true
        }}
        @value={{readonly @field.value}}
      />
    {{/if}}
  </template>
}
