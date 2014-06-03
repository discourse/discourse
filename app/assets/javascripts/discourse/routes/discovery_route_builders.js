/**
  A builder to create routes for topic discovery.

  @function buildTopicRoute
  @param {String} filter to create route for
**/
function buildTopicRoute(filter) {
  return Discourse.Route.extend({
    queryParams: {
      sort: { replace: true },
      ascending: { replace: true },
      status: { replace: true }
    },

    beforeModel: function() {
      this.controllerFor('navigation/default').set('filterMode', filter);
    },

    model: function(data, transaction) {

      var params = transaction.queryParams;

      // attempt to stop early cause we need this to be called before .sync
      Discourse.ScreenTrack.current().stop();

      var findOpts = {};
      if (params && params.order) { findOpts.order = params.order; }
      if (params && params.ascending) { findOpts.ascending = params.ascending; }
      if (params && params.status) { findOpts.status = params.status; }


      return Discourse.TopicList.list(filter, findOpts).then(function(list) {
        var tracking = Discourse.TopicTrackingState.current();
        if (tracking) {
          tracking.sync(list, filter);
          tracking.trackIncoming(filter);
        }
        return list;
      });
    },

    setupController: function(controller, model, trans) {

      controller.setProperties({
        order: Em.get(trans, 'queryParams.order'),
        ascending: Em.get(trans, 'queryParams.ascending')
      });

      var period = filter.indexOf('/') > 0 ? filter.split('/')[1] : '',
          filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0});

      if (filter === Discourse.Utilities.defaultHomepage()) {
        Discourse.set('title', '');
      } else {
        Discourse.set('title', I18n.t('filters.with_topics', {filter: filterText}));
      }

      this.controllerFor('discovery/topics').setProperties({
        model: model,
        category: null,
        period: period,
        selected: []
      });

      // If there's a draft, open the create topic composer
      if (model.draft) {
        var composer = this.controllerFor('composer');
        if (!composer.get('model.viewOpen')) {
          composer.open({
            action: Discourse.Composer.CREATE_TOPIC,
            draft: model.draft,
            draftKey: model.draft_key,
            draftSequence: model.draft_sequence
          });
        }
      }

      this.controllerFor('navigation/default').set('canCreateTopic', model.get('can_create_topic'));
    },

    renderTemplate: function() {
      this.render('navigation/default', { outlet: 'navigation-bar' });
      this.render('discovery/topics', { controller: 'discovery/topics', outlet: 'list-container' });
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

    afterModel: function(model, transaction) {
      var self = this,
          noSubcategories = params && !!params.no_subcategories,
          filterMode = "category/" + Discourse.Category.slugFor(model) + (noSubcategories ? "/none" : "") + "/l/" + filter,
          listFilter = "category/" + Discourse.Category.slugFor(model) + "/l/" + filter;

      this.controllerFor('search').set('searchContext', model.get('searchContext'));

      var opts = { category: model, filterMode: filterMode };
      opts.noSubcategories = params && params.no_subcategories;
      opts.canEditCategory = Discourse.User.currentProp('staff');

      opts.canChangeCategoryNotificationLevel = Discourse.User.current();
      this.controllerFor('navigation/category').setProperties(opts);

      var queryParams = transaction.queryParams;
      params = params || {};

      if (queryParams && queryParams.order) { params.order = queryParams.order; }
      if (queryParams && queryParams.ascending) { params.ascending = queryParams.ascending; }
      if (queryParams && queryParams.status) { params.status = queryParams.status; }

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
      var topics = this.get('topics'),
          period = filter.indexOf('/') > 0 ? filter.split('/')[1] : '',
          filterText = I18n.t('filters.' + filter.replace('/', '.') + '.title', {count: 0});

      Discourse.set('title', I18n.t('filters.with_category', { filter: filterText, category: model.get('name').capitalize() }));

      this.controllerFor('navigation/category').set('canCreateTopic', topics.get('can_create_topic'));
      this.controllerFor('discovery/topics').setProperties({
        model: topics,
        category: model,
        period: period,
        selected: [],
        noSubcategories: params && !!params.no_subcategories
      });

      this.set('topics', null);
    },

    renderTemplate: function() {
      this.render('navigation/category', { outlet: 'navigation-bar' });
      this.render('discovery/topics', { controller: 'discovery/topics', outlet: 'list-container' });
    },

    deactivate: function() {
      this._super();
      this.controllerFor('search').set('searchContext', null);
    },

    actions: {
      setNotification: function(notification_level){
        this.currentModel.setNotification(notification_level);
      }
    }
  });
}

// Finally, build all the routes with the helpers we created
Discourse.addInitializer(function() {
  Discourse.DiscoveryCategoryRoute = buildCategoryRoute('latest');
  Discourse.DiscoveryCategoryNoneRoute = buildCategoryRoute('latest', {no_subcategories: true});

  Discourse.Site.currentProp('filters').forEach(function(filter) {
    Discourse["Discovery" + filter.capitalize() + "Controller"] = Discourse.DiscoverySortableController.extend();
    Discourse["Discovery" + filter.capitalize() + "Route"] = buildTopicRoute(filter);
    Discourse["Discovery" + filter.capitalize() + "CategoryRoute"] = buildCategoryRoute(filter);
    Discourse["Discovery" + filter.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute(filter, {no_subcategories: true});
  });

  Discourse.Site.currentProp('periods').forEach(function(period) {
    Discourse["DiscoveryTop" + period.capitalize() + "Controller"] = Discourse.DiscoverySortableController.extend();
    Discourse["DiscoveryTop" + period.capitalize() + "Route"] = buildTopicRoute('top/' + period);
    Discourse["DiscoveryTop" + period.capitalize() + "CategoryRoute"] = buildCategoryRoute('top/' + period);
    Discourse["DiscoveryTop" + period.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute('top/' + period, {no_subcategories: true});
  });
}, true);
