import { array, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import SearchAdvancedCategoryChooser from "discourse/select-kit/components/search-advanced-category-chooser";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class Category extends FilterComponent {
  @service siteSettings;

  get category() {
    return this.args.filter?.default;
  }

  @action
  onChange(categoryId) {
    this.args.applyFilter(this.args.filter.id, categoryId || undefined);
  }

  <template>
    <div ...attributes>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="search-advanced-category-chooser category-chooser"
          @clearable={{true}}
          @descriptions={{false}}
          @disabled={{@filter.disabled}}
          @emit="ids"
          @legacyKind={{array
            "search-advanced-category-chooser"
            "category-chooser"
          }}
          @onChange={{this.onChange}}
          @permission="see"
          @placeholder={{i18n "category.all"}}
          @uncategorized={{true}}
          @value={{this.category}}
        />
      {{else}}
        <SearchAdvancedCategoryChooser
          @onChange={{this.onChange}}
          @options={{hash filterable=true disabled=@filter.disabled}}
          @value={{this.category}}
        />
      {{/if}}
    </div>
  </template>
}
