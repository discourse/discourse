/**
  A builder to create routes for topic discovery.

  @function buildTopicRoute
  @param {String} filter to create route for
**/
function buildTopicRoute(filter) {
  return Discourse.Route.extend({
    beforeModel: function() {
      this.controllerFor('navigationDefault').set('filterMode', filter);
    },

    model: function() {
      return Discourse.TopicList.list(filter).then(function(list) {
        var tracking = Discourse.TopicTrackingState.current();
        if (tracking) {
          tracking.sync(list, filter);
          tracking.trackIncoming(filter);
        }
        return list;
      });
    },

    setupController: function(controller, model) {
      var filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0});
      Discourse.set('title', I18n.t('filters.with_topics', {filter: filterText}));
      this.controllerFor('discoveryTopics').set('model', model);
      this.controllerFor('navigationDefault').set('canCreateTopic', model.get('can_create_topic'));
    },

    renderTemplate: function() {
      this.render('navigation/default', { outlet: 'navigation-bar' });
      this.render('discovery/topics', { controller: 'discoveryTopics', outlet: 'list-container' });
    }
  });
}

/**
  A builder to create routes for topic discovery within a category.

  @function buildTopicRoute
  @param {String} filter to create route for
  @param {Object} params with additional options
**/
function buildCategoryRoute(filter, params) {
  return Discourse.Route.extend({
    model: function(params) {
      return Discourse.Category.findBySlug(params.slug, params.parentSlug);
    },

    afterModel: function(model) {
      var self = this,
          noSubcategories = params && !!params.no_subcategories,
          filterMode = "category/" + Discourse.Category.slugFor(model) + (noSubcategories ? "/none" : "") + "/l/" + filter,
          listFilter = "category/" + Discourse.Category.slugFor(model) + "/l/" + filter;

      this.controllerFor('search').set('searchContext', model);

      var opts = { category: model, filterMode: filterMode };
      opts.noSubcategories = params && params.no_subcategories;
      opts.canEditCategory = Discourse.User.current('staff');
      this.controllerFor('navigationCategory').setProperties(opts);

      return Discourse.TopicList.list(listFilter, params).then(function(list) {
        var tracking = Discourse.TopicTrackingState.current();
        if (tracking) {
          tracking.sync(list, listFilter);
          tracking.trackIncoming(listFilter);
        }

        // If all the categories are the same, we can hide them
        var hideCategory = !list.get('topics').find(function (t) { return t.get('category') !== model; });
        list.set('hideCategory', hideCategory);
        self.set('topics', list);
      });
    },

    setupController: function(controller, model) {
      var topics = this.get('topics');

      var filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0});
      Discourse.set('title', I18n.t('filters.with_category', {filter: filterText, category: model.get('name').capitalize()}));
      this.controllerFor('discoveryTopics').set('model', topics);
      this.controllerFor('navigationCategory').set('canCreateTopic', topics.get('can_create_topic'));
      this.set('topics', null);
    },

    renderTemplate: function() {
      this.render('navigation/category', { outlet: 'navigation-bar' });
      this.render('discovery/topics', { controller: 'discoveryTopics', outlet: 'list-container' });
    },

    deactivate: function() {
      this._super();
      this.controllerFor('search').set('searchContext', null);
    }
  });
}

// Finally, build all the routes with the helpers we created
Discourse.addInitializer(function() {
  Discourse.DiscoveryController = Em.Controller.extend({});
  Discourse.DiscoveryCategoryRoute = buildCategoryRoute('latest');
  Discourse.DiscoveryCategoryNoneRoute = buildCategoryRoute('latest', {no_subcategories: true});

  Discourse.Site.currentProp('filters').forEach(function(filter) {
    Discourse["Discovery" + filter.capitalize() + "Route"] = buildTopicRoute(filter);
    Discourse["Discovery" + filter.capitalize() + "CategoryRoute"] = buildCategoryRoute(filter);
    Discourse["Discovery" + filter.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute(filter, {no_subcategories: true});
  });

  Discourse.Site.currentProp('periods').forEach(function(period) {
    Discourse["DiscoveryTop" + period.capitalize() + "Route"] = buildTopicRoute('top/' + period);
    Discourse["DiscoveryTop" + period.capitalize() + "CategoryRoute"] = buildCategoryRoute('top/' + period);
    Discourse["DiscoveryTop" + period.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute('top/' + period, {no_subcategories: true});
  });
}, true);
