/**
  Handles the controller for the default navigation within discovery.

  @class NavigationDefaultController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.NavigationDefaultController = Discourse.Controller.extend({
  needs: ['composer', 'discoveryTopics'],

  actions: {
    createTopic: function() {
      var topicsController = this.get('controllers.discoveryTopics');
      this.get('controllers.composer').open({
        categoryId: this.get('category.id'),
        action: Discourse.Composer.CREATE_TOPIC,
        draft: topicsController.get('draft'),
        draftKey: topicsController.get('draft_key'),
        draftSequence: topicsController.get('draft_sequence')
      });
    }
  },

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
