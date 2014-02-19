/**
  Renders a drop down for selecting a category

  @class CategoryDropComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryDropComponent = Ember.Component.extend({
  classNameBindings: ['category::no-category', 'categories:has-drop'],
  tagName: 'li',

  iconClass: function() {
    if (this.get('expanded')) { return "fa fa-caret-down"; }
    return "fa fa-caret-right";
  }.property('expanded'),

  allCategoriesUrl: function() {
    if (this.get('subCategory')) {
      return this.get('parentCategory.url') || "/";
    } else {
      return "/";
    }
  }.property('parentCategory.url', 'subCategory'),

  noCategoriesUrl: function() {
    return this.get('parentCategory.url') + "/none";
  }.property('parentCategory.url'),

  allCategoriesLabel: function() {
    if (this.get('subCategory')) {
      return I18n.t('categories.all_subcategories', {categoryName: this.get('parentCategory.name')});
    }
    return I18n.t('categories.all');
  }.property('category'),

  badgeStyle: function() {
    var category = this.get('category');
    if (category) {
      return Discourse.HTML.categoryStyle(category);
    } else {
      return "background-color: #eee; color: #333";
    }
  }.property('category'),

  actions: {
    expand: function() {
      if (this.get('expanded')) {
        this.close();
        return;
      }

      if (this.get('categories')) {
        this.set('expanded', true);
      }
      var self = this,
          $dropdown = this.$()[0];

      this.$('a[data-drop-close]').on('click.category-drop', function() {
        self.close();
      });

      $('html').on('click.category-drop', function(e) {
        var $target = $(e.target),
            closest = $target.closest($dropdown);

        return ($(e.currentTarget).hasClass('badge-category') || (closest.length && closest[0] === $dropdown)) ? true : self.close();
      });
    }
  },

  categoryChanged: function() {
    this.close();
  }.observes('category', 'parentCategory'),

  close: function() {
    $('html').off('click.category-drop');
    this.$('a[data-drop-close]').off('click.category-drop');
    this.set('expanded', false);
  },

  willDestroyElement: function() {
    $('html').off('click.category-drop');
    this.$('a[data-drop-close]').off('click.category-drop');
  }

});
