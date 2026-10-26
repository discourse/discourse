import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { splitString } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";

export default class SettingFieldCategoryList extends Component {
  @service siteSettings;

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
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectCategory
            class="category-selector"
            @onChange={{this.onChangeCategories}}
            @value={{this.selectedCategories}}
          />
        {{else}}
          <CategorySelector
            @categories={{this.selectedCategories}}
            @onChange={{this.onChangeCategories}}
          />
        {{/if}}
      </div>
    </@field.Control>
  </template>
}
