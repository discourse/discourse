import { action, computed } from "@ember/object";
import Category from "discourse/models/category";
import Component from "@ember/component";

export default class CategoryList extends Component {
  @computed("value")
  get selectedCategories() {
    return Category.findByIds(this.value.split("|").filter(Boolean));
  }

  @action
  onChangeSelectedCategories(value) {
    this.set("value", (value || []).mapBy("id").join("|"));
  }
}
