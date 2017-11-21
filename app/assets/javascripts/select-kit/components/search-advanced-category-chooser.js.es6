import CategoryChooserComponent from "select-kit/components/category-chooser";
import Category from "discourse/models/category";

export default CategoryChooserComponent.extend({
  pluginApiIdentifiers: ["advanced-search-category-chooser"],
  rootNone: true,
  rootNoneLabel: "category.all",
  allowUncategorized: true,
  clearable: true,

  mutateValue(value) {
    if (value) {
      this.set("value", Category.findById(value));
    } else {
      this.set("value", null);
    }
  },

  computeValue(category) { if (category) return category.id; }
});
