import { and, none } from "@ember/object/computed";
import FilterModeMixin from "discourse/mixins/filter-mode";
import NavigationDefaultController from "discourse/controllers/navigation/default";

export default NavigationDefaultController.extend(FilterModeMixin, {
  showingParentCategory: none("category.parentCategory"),
  showingSubcategoryList: and(
    "category.show_subcategory_list",
    "showingParentCategory"
  ),
});
