import Category from "discourse/models/category";
import { action, computed } from "@ember/object";
import BaseField from "./da-base-field";

export default class CategoriesField extends BaseField {
  @computed("field.metadata.value")
  get categories() {
    const ids = this.field?.metadata?.value || [];
    return ids.map((id) => Category.findById(id)).filter(Boolean);
  }

  @action
  onChangeCategories(categories) {
    this.set("field.metadata.value", categories.mapBy("id"));
  }
}
