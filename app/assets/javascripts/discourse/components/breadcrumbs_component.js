Discourse.DiscourseBreadcrumbsComponent = Ember.Component.extend({
  classNames: ['category-breadcrumb'],
  tagName: 'ol',
  parentCategory: Em.computed.alias('category.parentCategory'),

  parentCategories: Em.computed.filter('categories', function(c) {
    return !c.get('parentCategory');
  }),

  targetCategory: function() {
    // Note we can't use Em.computed.or here because it returns a boolean not the object
    return this.get('parentCategory') || this.get('category');
  }.property('parentCategory', 'category'),

  childCategories: Em.computed.filter('categories', function(c) {
    return c.get('parentCategory') === this.get('targetCategory');
  })

});
