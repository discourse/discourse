import computed from 'ember-addons/ember-computed-decorators';
import SelectBoxKitRowComponent from "select-box-kit/components/select-box-kit/select-box-kit-row";
import Category from "discourse/models/category";

export default SelectBoxKitRowComponent.extend({
  classNameBindings: ["isUncategorized"],

  @computed("content.id")
  isUncategorized(categoryId) {
    const category = Category.findById(categoryId);
    return category.get("isUncategorizedCategory");
  }
});
