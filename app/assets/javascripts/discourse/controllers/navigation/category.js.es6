import NavigationDefaultController from "discourse/controllers/navigation/default";

export default NavigationDefaultController.extend({
  showingParentCategory: Em.computed.none("category.parentCategory"),
  showingSubcategoryList: Em.computed.and(
    "category.show_subcategory_list",
    "showingParentCategory"
  )
});
