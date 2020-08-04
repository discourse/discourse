import { none, and } from "@ember/object/computed";
import NavigationDefaultController from "discourse/controllers/navigation/default";
import FilterModeMixin from "discourse/mixins/filter-mode";

export default NavigationDefaultController.extend(FilterModeMixin, {
  showingParentCategory: none("category.parentCategory"),
  showingSubcategoryList: and(
    "category.show_subcategory_list",
    "showingParentCategory"
  )
});
