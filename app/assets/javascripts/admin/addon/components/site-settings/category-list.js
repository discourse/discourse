import Component from "@ember/component";
import { action, computed } from "@ember/object";
import Category from "discourse/models/category";

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
