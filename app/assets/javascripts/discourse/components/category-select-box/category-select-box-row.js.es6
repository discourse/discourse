import computed from 'ember-addons/ember-computed-decorators';
import SelectBoxRowComponent from "discourse/components/select-box/select-box-row";
import Category from "discourse/models/category";

export default SelectBoxRowComponent.extend({
  classNameBindings: ["isUncategorized"],

  @computed("content")
  isUncategorized(content) {
    const category = Category.findById(content.id);
    return category.get("isUncategorizedCategory");
  }
});
