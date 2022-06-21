import DiscoverySortableController from "discourse/controllers/discovery-sortable";
import Site from "discourse/models/site";
import TagShowRoute from "discourse/routes/tag-show";
import User from "discourse/models/user";
import buildCategoryRoute from "discourse/routes/build-category-route";
import buildTopicRoute from "discourse/routes/build-topic-route";

export default {
  after: "inject-discourse-objects",
  name: "dynamic-route-builders",

  initialize(registry, app) {
    app.register(
      "controller:discovery.category",
      DiscoverySortableController.extend()
    );
    app.register(
      "controller:discovery.category-none",
      DiscoverySortableController.extend()
    );
    app.register(
      "controller:discovery.category-all",
      DiscoverySortableController.extend()
    );

    app.register("route:discovery.category", buildCategoryRoute("default"));
    app.register(
      "route:discovery.category-none",
      buildCategoryRoute("default", {
        no_subcategories: true,
      })
    );
    app.register(
      "route:discovery.category-all",
      buildCategoryRoute("default", {
        no_subcategories: false,
      })
    );

    const site = Site.current();
    site.get("filters").forEach((filter) => {
      const filterDasherized = filter.dasherize();
      app.register(
        `controller:discovery.${filterDasherized}`,
        DiscoverySortableController.extend()
      );
      app.register(
        `controller:discovery.${filterDasherized}-category`,
        DiscoverySortableController.extend()
      );
      app.register(
        `controller:discovery.${filterDasherized}-category-none`,
        DiscoverySortableController.extend()
      );

      if (filter === "top") {
        app.register(
          "route:discovery.top",
          buildTopicRoute("top", {
            actions: {
              willTransition() {
                User.currentProp("should_be_redirected_to_top", false);
                User.currentProp("redirected_to_top.reason", null);
                return this._super(...arguments);
              },
            },
          })
        );
      } else {
        app.register(
          `route:discovery.${filterDasherized}`,
          buildTopicRoute(filter)
        );
      }

      app.register(
        `route:discovery.${filterDasherized}-category`,
        buildCategoryRoute(filter)
      );
      app.register(
        `route:discovery.${filterDasherized}-category-none`,
        buildCategoryRoute(filter, { no_subcategories: true })
      );
    });

    app.register("route:tags.show-category", TagShowRoute.extend());
    app.register(
      "route:tags.show-category-none",
      TagShowRoute.extend({
        noSubcategories: true,
      })
    );
    app.register(
      "route:tags.show-category-all",
      TagShowRoute.extend({
        noSubcategories: false,
      })
    );

    site.get("filters").forEach(function (filter) {
      const filterDasherized = filter.dasherize();

      app.register(
        `route:tag.show-${filterDasherized}`,
        TagShowRoute.extend({
          navMode: filter,
        })
      );
      app.register(
        `route:tag.show-${filterDasherized}-category`,
        TagShowRoute.extend({ navMode: filter })
      );
      app.register(
        `route:tag.show-${filterDasherized}-category-none`,
        TagShowRoute.extend({ navMode: filter, noSubcategories: true })
      );
      app.register(
        `route:tag.show-${filterDasherized}-category-all`,
        TagShowRoute.extend({ navMode: filter, noSubcategories: false })
      );
    });
  },
};
