import NavigationDefaultController from 'discourse/controllers/navigation/default';

export default NavigationDefaultController.extend({
  subcategoryListSetting: Discourse.computed.setting('show_subcategory_list'),
  showingParentCategory: Em.computed.none('category.parentCategory'),
  showingSubcategoryList: Em.computed.and('subcategoryListSetting', 'showingParentCategory'),

  navItems: function() {
    if (this.get('showingSubcategoryList')) { return []; }
    return Discourse.NavItem.buildList(this.get('category'), { noSubcategories: this.get('noSubcategories') });
  }.property('category', 'noSubcategories')
});
