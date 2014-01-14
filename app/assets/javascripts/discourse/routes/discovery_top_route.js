/**
  Handles the routes related to "Top"

  @class DiscoveryTopRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopRoute = Discourse.Route.extend({
  model: function(params) {
    return Discourse.Category.findBySlug(params.slug, params.parentSlug);
  },

  beforeModel: function() {
    this.controllerFor('navigationCategory').set('filterMode', 'top');
  },

  afterModel: function(model) {
    var self = this;
    return Discourse.TopList.find(null, model).then(function(list) {
      self.set('topics', list);
    });
  },

  renderTemplate: function() {
    this.render('navigation/category', { outlet: 'navigation-bar' });
    this.render('discovery/top', { outlet: 'list-container' });
  },

  setupController: function(controller, model) {
    this.controllerFor('discoveryTop').set('model', this.get('topics'));
    this.controllerFor('discoveryTop').set('category', model);
    this.controllerFor('navigationCategory').set('category', model);
    Discourse.set('title', I18n.t('filters.top.title'));
    this.set('topics', null);
  }
});

Discourse.DiscoveryTopCategoryRoute = Discourse.DiscoveryTopRoute.extend({});
Discourse.DiscoveryTopCategoryNoneRoute = Discourse.DiscoveryTopRoute.extend({});
