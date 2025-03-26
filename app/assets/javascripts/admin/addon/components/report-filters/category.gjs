import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import FilterComponent from "admin/components/report-filters/filter";
import SearchAdvancedCategoryChooser from "select-kit/components/search-advanced-category-chooser";

export default class Category extends FilterComponent {
  @readOnly("filter.default") category;

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
