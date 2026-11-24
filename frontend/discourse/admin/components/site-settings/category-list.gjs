import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";

export default class CategoryList extends Component {
  @service siteSettings;

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
    this.args.changeValueCallback(
      (value || []).map((item) => item.id).join("|")
    );
  }

  <template>
    <div ...attributes {{didUpdate this.valueChanged @value}}>
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectCategory
          class="category-selector"
          @multiple={{true}}
          @onChange={{this.onChangeSelectedCategories}}
          @texts={{hash ariaLabel=@label}}
          @value={{this.selectedCategories}}
        />
      {{else}}
        <CategorySelector
          @categories={{this.selectedCategories}}
          @onChange={{this.onChangeSelectedCategories}}
        />
      {{/if}}
    </div>
  </template>
}
