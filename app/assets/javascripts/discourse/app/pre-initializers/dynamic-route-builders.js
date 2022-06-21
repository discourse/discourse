import DiscoverySortableController from "discourse/controllers/discovery-sortable";
import Site from "discourse/models/site";
import TagShowRoute from "discourse/routes/tag-show";
import User from "discourse/models/user";
import buildCategoryRoute from "discourse/routes/build-category-route";
import buildTopicRoute from "discourse/routes/build-topic-route";
import { capitalize } from "@ember/string";

export default {
  after: "inject-discourse-objects",
  name: "dynamic-route-builders",

  initialize(registry, app) {
    app.DiscoveryCategoryController = DiscoverySortableController.extend();
    app.DiscoveryCategoryNoneController = DiscoverySortableController.extend();
    app.DiscoveryCategoryAllController = DiscoverySortableController.extend();

    app.DiscoveryCategoryRoute = buildCategoryRoute("default");
    app.DiscoveryCategoryNoneRoute = buildCategoryRoute("default", {
      no_subcategories: true,
    });
    app.DiscoveryCategoryAllRoute = buildCategoryRoute("default", {
      no_subcategories: false,
    });

    const site = Site.current();
    site.get("filters").forEach((filter) => {
      const filterCapitalized = capitalize(filter);
      app[
        `Discovery${filterCapitalized}Controller`
      ] = DiscoverySortableController.extend();
      app[
        `Discovery${filterCapitalized}CategoryController`
      ] = DiscoverySortableController.extend();
      app[
        `Discovery${filterCapitalized}CategoryNoneController`
      ] = DiscoverySortableController.extend();

      if (filter === "top") {
        app.DiscoveryTopRoute = buildTopicRoute("top", {
          actions: {
            willTransition() {
              User.currentProp("should_be_redirected_to_top", false);
              User.currentProp("redirected_to_top.reason", null);
              return this._super(...arguments);
            },
          },
        });
      } else {
        app[`Discovery${filterCapitalized}Route`] = buildTopicRoute(filter);
      }

      app[`Discovery${filterCapitalized}CategoryRoute`] = buildCategoryRoute(
        filter
      );
      app[
        `Discovery${filterCapitalized}CategoryNoneRoute`
      ] = buildCategoryRoute(filter, { no_subcategories: true });
    });

    app["TagsShowCategoryRoute"] = TagShowRoute.extend();
    app["TagsShowCategoryNoneRoute"] = TagShowRoute.extend({
      noSubcategories: true,
    });
    app["TagsShowCategoryAllRoute"] = TagShowRoute.extend({
      noSubcategories: false,
    });

    site.get("filters").forEach(function (filter) {
      app["TagShow" + capitalize(filter) + "Route"] = TagShowRoute.extend({
        navMode: filter,
      });
      app[
        "TagsShowCategory" + capitalize(filter) + "Route"
      ] = TagShowRoute.extend({ navMode: filter });
      app[
        "TagsShowCategoryNone" + capitalize(filter) + "Route"
      ] = TagShowRoute.extend({ navMode: filter, noSubcategories: true });
      app[
        "TagsShowCategoryAll" + capitalize(filter) + "Route"
      ] = TagShowRoute.extend({ navMode: filter, noSubcategories: false });
    });
  },
};
