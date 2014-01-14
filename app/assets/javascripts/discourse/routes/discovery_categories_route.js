/**
  The route for handling the "Categories" view

  @class DiscoveryCategoriesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryCategoriesRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('navigation/categories', { outlet: 'navigation-bar' });
    this.render('discovery/categories', { outlet: 'list-container' });
  },

  beforeModel: function() {
    this.controllerFor('navigationCategories').set('filterMode', 'categories');
  },

  model: function() {
    return Discourse.CategoryList.list('categories').then(function(list) {
      var tracking = Discourse.TopicTrackingState.current();
      if (tracking) {
        tracking.sync(list, 'categories');
        tracking.trackIncoming('categories');
      }
      return list;
    });
  }, 

  setupController: function(controller, model) {
    controller.set('model', model);
    Discourse.set('title', I18n.t('filters.categories.title'));
    this.controllerFor('navigationCategories').set('canCreateCategory', model.get('can_create_category'));
  },

  actions: {
    createCategory: function() {
      Discourse.Route.showModal(this, 'editCategory', Discourse.Category.create({
        color: 'AB9364', text_color: 'FFFFFF', hotness: 5, group_permissions: [{group_name: 'everyone', permission_type: 1}],
        available_groups: Discourse.Site.current().group_names
      }));
      this.controllerFor('editCategory').set('selectedTab', 'general');
    }
  },
});
