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
    if (c.id === Discourse.Site.currentProp("uncategorized_category_id") && !Discourse.SiteSettings.allow_uncategorized_topics) {
      // Don't show "uncategorized" if allow_uncategorized_topics setting is false.
      return false;
    }
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
    var firstCategory = this.get('firstCategory');
    if (!firstCategory) { return; }

    return this.get('categories').filter(function (c) {
      return c.get('parentCategory') === firstCategory;
    });
  }.property('firstCategory')

});
