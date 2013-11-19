/**
  A breadcrumb including category drop downs

  @class BreadCrumbsComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.BreadCrumbsComponent = Ember.Component.extend({
  classNames: ['category-breadcrumb'],
  tagName: 'ol',
  parentCategory: Em.computed.alias('category.parentCategory'),

  parentCategories: Em.computed.filter('categories', function(c) {
    return !c.get('parentCategory');
  }),

  firstCategory: function() {
    return this.get('parentCategory') || this.get('category');
  }.property('parentCategory', 'category'),

  secondCategory: function() {
    if (this.get('parentCategory')) return this.get('category');
    return null;
  }.property('category', 'parentCategory'),

  childCategories: function() {
    var self = this;
    return this.get('categories').filter(function (c) {
      return c.get('parentCategory') === self.get('firstCategory');
    });
  }.property('firstCategory')

});
