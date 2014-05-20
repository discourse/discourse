import NavigationDefaultController from 'discourse/controllers/navigation/default';

export default NavigationDefaultController.extend({
  navItems: function() {
    return Discourse.NavItem.buildList(this.get('category'), { noSubcategories: this.get('noSubcategories') });
  }.property('category', 'noSubcategories')
});

