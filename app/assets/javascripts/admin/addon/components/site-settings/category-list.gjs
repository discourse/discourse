import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import Category from "discourse/models/category";
import htmlSafe from "discourse-common/helpers/html-safe";
import SettingValidationMessage from "admin/components/setting-validation-message";
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

  async updateSelectedCategories() {
    await this.pendingCategoriesRequest;
    this.selectedCategories = await Category.asyncFindByIds(this.categoryIds);
  }

  @action
  valueChanged() {
    this.pendingCategoriesRequest = this.updateSelectedCategories();
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

      <div class="desc">{{htmlSafe this.setting.description}}</div>
      <SettingValidationMessage @message={{this.validationMessage}} />
    </div>
  </template>
}
