import Component from "@glimmer/component";
import { action } from "@ember/object";
import Category from "discourse/models/category";
import htmlSafe from "discourse-common/helpers/html-safe";
import SettingValidationMessage from "admin/components/setting-validation-message";
import CategorySelector from "select-kit/components/category-selector";

export default class CategoryList extends Component {
  get selectedCategories() {
    return Category.findByIds(this.args.value.split("|").filter(Boolean));
  }

  @action
  onChangeSelectedCategories(value) {
    this.args.changeValueCallback((value || []).mapBy("id").join("|"));
  }

  <template>
    <CategorySelector
      @categories={{this.selectedCategories}}
      @onChange={{this.onChangeSelectedCategories}}
    />

    <div class="desc">{{htmlSafe this.setting.description}}</div>
    <SettingValidationMessage @message={{this.validationMessage}} />
  </template>
}
