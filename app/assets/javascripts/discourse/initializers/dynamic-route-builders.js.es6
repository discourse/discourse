import buildCategoryRoute from 'discourse/routes/build-category-route';
import buildTopicRoute from 'discourse/routes/build-topic-route';

export default {
  name: 'dynamic-route-builders',
  after: 'register-discourse-location',

  initialize: function(container, app) {
    app.DiscoveryCategoryRoute = buildCategoryRoute('latest');
    app.DiscoveryParentCategoryRoute = buildCategoryRoute('latest');
    app.DiscoveryCategoryNoneRoute = buildCategoryRoute('latest', {no_subcategories: true});

    Discourse.Site.currentProp('filters').forEach(function(filter) {
      app["Discovery" + filter.capitalize() + "Controller"] = Discourse.DiscoverySortableController.extend();
      app["Discovery" + filter.capitalize() + "Route"] = buildTopicRoute(filter);
      app["Discovery" + filter.capitalize() + "CategoryRoute"] = buildCategoryRoute(filter);
      app["Discovery" + filter.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute(filter, {no_subcategories: true});
    });

    Discourse.Site.currentProp('periods').forEach(function(period) {
      app["DiscoveryTop" + period.capitalize() + "Controller"] = Discourse.DiscoverySortableController.extend();
      app["DiscoveryTop" + period.capitalize() + "Route"] = buildTopicRoute('top/' + period);
      app["DiscoveryTop" + period.capitalize() + "CategoryRoute"] = buildCategoryRoute('top/' + period);
      app["DiscoveryTop" + period.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute('top/' + period, {no_subcategories: true});
    });
  }
};
