import Component from "@ember/component";
import { action, computed } from "@ember/object";
import Category from "discourse/models/category";
import htmlSafe from "discourse-common/helpers/html-safe";
import SettingValidationMessage from "admin/components/setting-validation-message";
import CategorySelector from "select-kit/components/category-selector";

export default class CategoryList extends Component {
  @computed("value")
  get selectedCategories() {
    return Category.findByIds(this.value.split("|").filter(Boolean));
  }

  @action
  onChangeSelectedCategories(value) {
    this.set("value", (value || []).mapBy("id").join("|"));
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
