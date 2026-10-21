import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import SearchAdvancedCategoryChooser from "discourse/select-kit/components/search-advanced-category-chooser";

export default class Category extends FilterComponent {
  get category() {
    return this.args.filter?.default;
  }

  @action
  onChange(categoryId) {
    this.args.applyFilter(this.args.filter.id, categoryId || undefined);
  }

  <template>
    <div ...attributes>
      <SearchAdvancedCategoryChooser
        @onChange={{this.onChange}}
        @options={{hash filterable=true disabled=@filter.disabled}}
        @value={{this.category}}
      />
    </div>
  </template>
}
