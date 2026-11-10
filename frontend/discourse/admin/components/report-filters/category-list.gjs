import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import FilterComponent from "discourse/admin/components/report-filters/filter";
import Category from "discourse/models/category";
import MultipleCategoriesSelector from "discourse/select-kit/components/multiple-categories-selector";

export default class CategoryList extends FilterComponent {
  @tracked selectedCategories;

  constructor() {
    super(...arguments);
    this.selectedCategories = (this.args.filter?.default || [])
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
    const current = this.args.filter.default || [];

    // apply (and re-run the report) only once the picker closes, and only when
    // the selection actually changed, so each individual pick doesn't refetch
    if (
      ids.length === current.length &&
      ids.every((id) => current.includes(id))
    ) {
      return;
    }

    this.args.applyFilter(this.args.filter.id, ids.length ? ids : undefined);
  }

  <template>
    <div ...attributes>
      <MultipleCategoriesSelector
        @categories={{this.selectedCategories}}
        @onChange={{this.onChange}}
        @onClose={{this.onClose}}
        @options={{hash disabled=@filter.disabled none="category.all"}}
      />
    </div>
  </template>
}
