/**
  Handles the controller for the default navigation within discovery.

  @class NavigationDefaultController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.NavigationDefaultController = Discourse.Controller.extend({
  categories: function() {
    return Discourse.Category.list();
  }.property(),

  navItems: function() {
    return Discourse.NavItem.buildList();
  }.property()
});

Discourse.NavigationCategoryController = Discourse.NavigationDefaultController.extend({
  navItems: function() {
    return Discourse.NavItem.buildList(this.get('category'), { noSubcategories: this.get('noSubcategories') });
  }.property('category', 'noSubcategories')
});

Discourse.NavigationCategoriesController = Discourse.NavigationDefaultController.extend({});
