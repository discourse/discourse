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

  childCategories: function() {
    var self = this;
    return this.get('categories').filter(function (c) {
      return c.get('parentCategory') === self.get('targetCategory');
    });
  }.property('targetCategory')

});
