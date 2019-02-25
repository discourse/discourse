import NavigationDefaultController from "discourse/controllers/navigation/default";

export default NavigationDefaultController.extend({
  showingParentCategory: Ember.computed.none("category.parentCategory"),
  showingSubcategoryList: Ember.computed.and(
    "category.show_subcategory_list",
    "showingParentCategory"
  )
});
