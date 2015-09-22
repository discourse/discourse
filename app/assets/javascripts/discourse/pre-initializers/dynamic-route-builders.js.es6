import buildCategoryRoute from 'discourse/routes/build-category-route';
import buildTopicRoute from 'discourse/routes/build-topic-route';
import DiscoverySortableController from 'discourse/controllers/discovery-sortable';

export default {
  after: 'inject-discourse-objects',
  name: 'dynamic-route-builders',

  initialize(container, app) {
    app.DiscoveryCategoryRoute = buildCategoryRoute('latest');
    app.DiscoveryParentCategoryRoute = buildCategoryRoute('latest');
    app.DiscoveryCategoryNoneRoute = buildCategoryRoute('latest', {no_subcategories: true});

    const site = Discourse.Site.current();
    site.get('filters').forEach(function(filter) {
      app["Discovery" + filter.capitalize() + "Controller"] = DiscoverySortableController.extend();
      app["Discovery" + filter.capitalize() + "Route"] = buildTopicRoute(filter);
      app["Discovery" + filter.capitalize() + "CategoryRoute"] = buildCategoryRoute(filter);
      app["Discovery" + filter.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute(filter, {no_subcategories: true});
    });

    Discourse.DiscoveryTopRoute = buildTopicRoute('top', {
      actions: {
        willTransition: function() {
          this._super();
          Discourse.User.currentProp("should_be_redirected_to_top", false);
          Discourse.User.currentProp("redirected_to_top.reason", null);
          return true;
        }
      }
    });

    Discourse.DiscoveryTopCategoryRoute = buildCategoryRoute('top');
    Discourse.DiscoveryTopCategoryNoneRoute = buildCategoryRoute('top', {no_subcategories: true});
    site.get('periods').forEach(function(period) {
      app["DiscoveryTop" + period.capitalize() + "Controller"] = DiscoverySortableController.extend();
      app["DiscoveryTop" + period.capitalize() + "Route"] = buildTopicRoute('top/' + period);
      app["DiscoveryTop" + period.capitalize() + "CategoryRoute"] = buildCategoryRoute('top/' + period);
      app["DiscoveryTop" + period.capitalize() + "CategoryNoneRoute"] = buildCategoryRoute('top/' + period, {no_subcategories: true});
    });
  }
};
