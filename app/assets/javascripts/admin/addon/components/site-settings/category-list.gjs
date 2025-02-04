import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import Category from "discourse/models/category";
import CategorySelector from "select-kit/components/category-selector";

export default class CategoryList extends Component {
  @tracked selectedCategories = [];

  constructor() {
    super(...arguments);

    this.pendingCategoriesRequest = Promise.resolve();
    this.valueChanged();
  }

  get categoryIds() {
    return this.args.value.split("|").filter(Boolean);
  }

  async updateSelectedCategories(previousRequest) {
    const categories = await Category.asyncFindByIds(this.categoryIds);

    // This is to prevent a race. We want to ensure that the update to
    // selectedCategories for this request happens after the update for the
    // previous request.
    await previousRequest;

    this.selectedCategories = categories;
  }

  @action
  valueChanged() {
    const previousRequest = this.pendingCategoriesRequest;
    this.pendingCategoriesRequest =
      this.updateSelectedCategories(previousRequest);
  }

  @action
  onChangeSelectedCategories(value) {
    this.args.changeValueCallback((value || []).mapBy("id").join("|"));
  }

  <template>
    <div ...attributes {{didUpdate this.valueChanged @value}}>
      <CategorySelector
        @categories={{this.selectedCategories}}
        @onChange={{this.onChangeSelectedCategories}}
      />
    </div>
  </template>
}
