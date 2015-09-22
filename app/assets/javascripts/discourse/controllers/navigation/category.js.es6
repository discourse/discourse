import computed from "ember-addons/ember-computed-decorators";
import NavigationDefaultController from 'discourse/controllers/navigation/default';
import { setting } from 'discourse/lib/computed';

export default NavigationDefaultController.extend({
  subcategoryListSetting: setting('show_subcategory_list'),
  showingParentCategory: Em.computed.none('category.parentCategory'),
  showingSubcategoryList: Em.computed.and('subcategoryListSetting', 'showingParentCategory'),

  @computed("showingSubcategoryList", "category", "noSubcategories")
  navItems(showingSubcategoryList, category, noSubcategories) {
    if (showingSubcategoryList) { return []; }
    return Discourse.NavItem.buildList(category, { noSubcategories });
  }
});
