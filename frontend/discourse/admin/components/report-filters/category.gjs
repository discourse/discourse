import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import SearchAdvancedCategoryChooser from "discourse/select-kit/components/search-advanced-category-chooser";

export default class Category extends FilterComponent {
  @computed("filter.default")
  get category() {
    return this.filter?.default;
  }

  @action
  onChange(categoryId) {
    this.applyFilter(this.filter.id, categoryId || undefined);
  }

  <template>
    <SearchAdvancedCategoryChooser
      @value={{this.category}}
      @onChange={{this.onChange}}
      @options={{hash filterable=true disabled=this.filter.disabled}}
    />
  </template>
}
