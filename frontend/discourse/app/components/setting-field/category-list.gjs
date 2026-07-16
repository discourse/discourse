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
    this.loadCategories();
  }

  get categoryIds() {
    return splitString(this.args.field.value, "|");
  }

  @action
  async loadCategories() {
    if (this.categoryIds.length) {
      this.selectedCategories = await Category.asyncFindByIds(this.categoryIds);
    } else {
      this.selectedCategories = [];
    }
  }

  @action
  onChangeCategories(categories) {
    this.args.field.set((categories || []).map((c) => c.id).join("|"));
  }

  <template>
    <@field.Control>
      <div {{didUpdate this.loadCategories @field.value}}>
        <CategorySelector
          @categories={{this.selectedCategories}}
          @onChange={{this.onChangeCategories}}
        />
      </div>
    </@field.Control>
  </template>
}
