import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";

export default class CategoryList extends FilterComponent {
  @tracked selectedCategories;

  init() {
    super.init(...arguments);
    this.selectedCategories = (this.filter?.default || [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
  }

  @action
  onChange(categories) {
    this.selectedCategories = categories;
  }

  @action
  onClose() {
    const ids = this.selectedCategories.map((category) => category.id);
    const current = this.filter.default || [];

    // apply (and re-run the report) only once the picker closes, and only when
    // the selection actually changed, so each individual pick doesn't refetch
    if (
      ids.length === current.length &&
      ids.every((id) => current.includes(id))
    ) {
      return;
    }

    this.applyFilter(this.filter.id, ids.length ? ids : undefined);
  }

  <template>
    <CategorySelector
      @categories={{this.selectedCategories}}
      @onChange={{this.onChange}}
      @onClose={{this.onClose}}
      @options={{hash disabled=this.filter.disabled none="category.all"}}
    />
  </template>
}
