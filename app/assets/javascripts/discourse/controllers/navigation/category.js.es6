import { none, and } from "@ember/object/computed";
import NavigationDefaultController from "discourse/controllers/navigation/default";

export default NavigationDefaultController.extend({
  showingParentCategory: none("category.parentCategory"),
  showingSubcategoryList: and(
    "category.show_subcategory_list",
    "showingParentCategory"
  )
});
