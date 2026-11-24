import { cached } from "@glimmer/tracking";
import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import Category from "discourse/models/category";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import CategorySelector from "discourse/select-kit/components/category-selector";
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
        ? Category.asyncFindByIds(ids)
        : Category.findByIds(ids)
    );
  }

  get placeholder() {
    return this.args.placeholder ? i18n(this.args.placeholder) : undefined;
  }

  @action
  handleChange(value) {
    if (this.args.multiple) {
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
        @maximum={{@maximum}}
        @multiple={{@multiple}}
        @onChange={{this.handleChange}}
        @permission={{@permission}}
        @subcategories={{@subcategories}}
        @texts={{hash ariaLabel=@field.title placeholder=this.placeholder}}
        @uncategorized={{@uncategorized}}
        @value={{readonly @field.value}}
      />
    {{else if @multiple}}
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
