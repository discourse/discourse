Discourse.DiscourseBreadcrumbsComponent = Ember.Component.extend({
  classNames: ['category-breadcrumb'],
  tagName: 'ol',
  parentCategory: Em.computed.alias('category.parentCategory')
});
