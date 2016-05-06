import buildCategoryRoute from 'discourse/routes/build-category-route';
import buildTopicRoute from 'discourse/routes/build-topic-route';
import DiscoverySortableController from 'discourse/controllers/discovery-sortable';
import TagsShowRoute from 'discourse/routes/tags-show';

export default {
  after: 'inject-discourse-objects',
  name: 'dynamic-route-builders',

  initialize(registry, app) {
    app.DiscoveryCategoryController = DiscoverySortableController.extend();
    app.DiscoveryParentCategoryController = DiscoverySortableController.extend();
    app.DiscoveryCategoryNoneController = DiscoverySortableController.extend();
    app.DiscoveryCategoryWithIDController = DiscoverySortableController.extend();

    app.DiscoveryCategoryRoute = buildCategoryRoute('latest');
    app.DiscoveryParentCategoryRoute = buildCategoryRoute('latest');
    app.DiscoveryCategoryNoneRoute = buildCategoryRoute('latest', {no_subcategories: true});

    const site = Discourse.Site.current();
    site.get('filters').forEach(filter => {
      const filterCapitalized = filter.capitalize();
      app[`Discovery${filterCapitalized}Controller`] = DiscoverySortableController.extend();
      app[`Discovery${filterCapitalized}CategoryController`] = DiscoverySortableController.extend();
      app[`Discovery${filterCapitalized}ParentCategoryController`] = DiscoverySortableController.extend();
      app[`Discovery${filterCapitalized}CategoryNoneController`] = DiscoverySortableController.extend();
      app[`Discovery${filterCapitalized}Route`] = buildTopicRoute(filter);
      app[`Discovery${filterCapitalized}CategoryRoute`] = buildCategoryRoute(filter);
      app[`Discovery${filterCapitalized}ParentCategoryRoute`] = buildCategoryRoute(filter);
      app[`Discovery${filterCapitalized}CategoryNoneRoute`] = buildCategoryRoute(filter, {no_subcategories: true});
    });

    Discourse.DiscoveryTopController = DiscoverySortableController.extend();
    Discourse.DiscoveryTopCategoryController = DiscoverySortableController.extend();
    Discourse.DiscoveryTopParentCategoryController = DiscoverySortableController.extend();
    Discourse.DiscoveryTopCategoryNoneController = DiscoverySortableController.extend();

    Discourse.DiscoveryTopRoute = buildTopicRoute('top', {
      actions: {
        willTransition() {
          Discourse.User.currentProp("should_be_redirected_to_top", false);
          Discourse.User.currentProp("redirected_to_top.reason", null);
          return this._super();
        }
      }
    });
    Discourse.DiscoveryTopCategoryRoute = buildCategoryRoute('top');
    Discourse.DiscoveryTopParentCategoryRoute = buildCategoryRoute('top');
    Discourse.DiscoveryTopCategoryNoneRoute = buildCategoryRoute('top', {no_subcategories: true});

    site.get('periods').forEach(period => {
      const periodCapitalized = period.capitalize();
      app[`DiscoveryTop${periodCapitalized}Controller`] = DiscoverySortableController.extend();
      app[`DiscoveryTop${periodCapitalized}CategoryController`] = DiscoverySortableController.extend();
      app[`DiscoveryTop${periodCapitalized}ParentCategoryController`] = DiscoverySortableController.extend();
      app[`DiscoveryTop${periodCapitalized}CategoryNoneController`] = DiscoverySortableController.extend();
      app[`DiscoveryTop${periodCapitalized}Route`] = buildTopicRoute('top/' + period);
      app[`DiscoveryTop${periodCapitalized}CategoryRoute`] = buildCategoryRoute('top/' + period);
      app[`DiscoveryTop${periodCapitalized}ParentCategoryRoute`] = buildCategoryRoute('top/' + period);
      app[`DiscoveryTop${periodCapitalized}CategoryNoneRoute`] = buildCategoryRoute('top/' + period, {no_subcategories: true});
    });

    app["TagsShowCategoryRoute"] = TagsShowRoute.extend();
    app["TagsShowParentCategoryRoute"] = TagsShowRoute.extend();

    site.get('filters').forEach(function(filter) {
      app["TagsShow" + filter.capitalize() + "Route"] = TagsShowRoute.extend({ filterMode: filter });
      app["TagsShowCategory" + filter.capitalize() + "Route"] = TagsShowRoute.extend({ filterMode: filter });
      app["TagsShowParentCategory" + filter.capitalize() + "Route"] = TagsShowRoute.extend({ filterMode: filter });
    });
  }
};
