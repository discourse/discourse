import discourseComputed from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import { action } from "@ember/object";
import BaseField from "./da-base-field";

export default class CategoriesField extends BaseField {
  @discourseComputed("field.metadata.value")
  categories(ids) {
    return (ids || []).map((id) => Category.findById(id)).filter(Boolean);
  }

  @action
  onChangeCategories(categories) {
    this.set("field.metadata.value", categories.mapBy("id"));
  }
}
