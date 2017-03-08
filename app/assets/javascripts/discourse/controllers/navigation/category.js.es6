import computed from "ember-addons/ember-computed-decorators";
import NavigationDefaultController from 'discourse/controllers/navigation/default';

export default NavigationDefaultController.extend({
  showingParentCategory: Em.computed.none('category.parentCategory'),
  showingSubcategoryList: Em.computed.and('category.show_subcategory_list', 'showingParentCategory'),

  @computed("showingSubcategoryList", "category", "noSubcategories")
  navItems(showingSubcategoryList, category, noSubcategories) {
    return Discourse.NavItem.buildList(category, { noSubcategories });
  }
});
