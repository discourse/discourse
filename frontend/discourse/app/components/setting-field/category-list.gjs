import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { splitString } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";

export default class SettingFieldCategoryList extends Component {
  @tracked selectedCategories = [];

  constructor() {
    super(...arguments);
    this.pendingCategoriesRequest = Promise.resolve();
    this.valueChanged();
  }

  get categoryIds() {
    return splitString(this.args.field.value, "|");
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
  onChangeCategories(categories) {
    this.args.field.set((categories || []).map((c) => c.id).join("|"));
  }

  <template>
    <@field.Control>
      <div {{didUpdate this.valueChanged @field.value}}>
        <CategorySelector
          @categories={{this.selectedCategories}}
          @onChange={{this.onChangeCategories}}
        />
      </div>
    </@field.Control>
  </template>
}
