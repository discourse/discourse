/**
  Handles the routes related to 'Top'

  @class DiscoveryTopRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopRoute = Discourse.Route.extend({
  beforeModel: function() {
    this.controllerFor('navigationDefault').set('filterMode', 'top');
  },

  model: function() {
    return Discourse.TopList.find();
  },

  setupController: function(controller, model) {
    var filterText = I18n.t('filters.top.title');
    Discourse.set('title', I18n.t('filters.with_topics', {filter: filterText}));
    this.controllerFor('discoveryTop').setProperties({ model: model, category: null });
    this.controllerFor('navigationDefault').set('canCreateTopic', model.get('can_create_topic'));
  },

  renderTemplate: function() {
    this.render('navigation/default', { outlet: 'navigation-bar' });
    this.render('discovery/top', { outlet: 'list-container' });
  }
});

/**
  Handles the routes related to 'Top' within a category

  @class DiscoveryTopCategoryRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.DiscoveryTopCategoryRoute = Discourse.Route.extend({
  model: function(params) {
    return Discourse.Category.findBySlug(params.slug, params.parentSlug);
  },

  afterModel: function(model) {
    var self = this,
               noSubcategories = this.get('no_subcategories'),
               filterMode = 'category/' + Discourse.Category.slugFor(model) + (noSubcategories ? '/none' : '') + '/l/top';

    this.controllerFor('search').set('searchContext', model);

    var opts = { category: model, filterMode: filterMode};
    opts.noSubcategories = noSubcategories;
    opts.canEditCategory = Discourse.User.current('staff');
    this.controllerFor('navigationCategory').setProperties(opts);

    return Discourse.TopList.find(filterMode).then(function(list) {
      // If all the categories are the same, we can hide them
      var hideCategory = !_.any(Discourse.Site.currentProp('periods'), function(period){
        if (list[period]) {
          return list[period].get('topics').find(function(t) { return t.get('category') !== model; });
        }
        return false;
      });
      list.set('hideCategory', hideCategory);
      self.set('topList', list);
    });
  },

  setupController: function(controller, model) {
    var topList = this.get('topList');
    var filterText = I18n.t('filters.top.title');
    Discourse.set('title', I18n.t('filters.with_category', {filter: filterText, category: model.get('name').capitalize()}));
    this.controllerFor('navigationCategory').set('canCreateTopic', topList.get('can_create_topic'));
    this.controllerFor('discoveryTop').setProperties({
      model: topList,
      category: model,
      noSubcategories: this.get('no_subcategories')
    });
    this.set('topList', null);
  },

  renderTemplate: function() {
    this.render('navigation/category', { outlet: 'navigation-bar' });
    this.render('discovery/top', { controller: 'discoveryTop', outlet: 'list-container' });
  },

  deactivate: function() {
    this._super();
    this.controllerFor('search').set('searchContext', null);
  }
});

Discourse.DiscoveryTopCategoryNoneRoute = Discourse.DiscoveryTopCategoryRoute.extend({no_subcategories: true});
