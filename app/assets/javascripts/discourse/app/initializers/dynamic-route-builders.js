import DiscoverySortableController from "discourse/controllers/discovery-sortable";
import Site from "discourse/models/site";
import TagShowRoute from "discourse/routes/tag-show";
import buildCategoryRoute from "discourse/routes/build-category-route";
import buildTopicRoute from "discourse/routes/build-topic-route";
import { dasherize } from "@ember/string";

export default {
  after: "inject-discourse-objects",

  initialize(app) {
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

    app.register(
      "route:discovery.category",
      buildCategoryRoute({ filter: "default" })
    );
    app.register(
      "route:discovery.category-none",
      buildCategoryRoute({ filter: "default", no_subcategories: true })
    );
    app.register(
      "route:discovery.category-all",
      buildCategoryRoute({ filter: "default", no_subcategories: false })
    );

    const site = Site.current();
    site.get("filters").forEach((filter) => {
      const filterDasherized = dasherize(filter);
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

      app.register(
        `route:discovery.${filterDasherized}`,
        buildTopicRoute(filter)
      );

      app.register(
        `route:discovery.${filterDasherized}-category`,
        buildCategoryRoute({ filter })
      );
      app.register(
        `route:discovery.${filterDasherized}-category-none`,
        buildCategoryRoute({ filter, no_subcategories: true })
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
      const filterDasherized = dasherize(filter);

      app.register(
        `route:tag.show-${filterDasherized}`,
        TagShowRoute.extend({
          navMode: filter,
        })
      );
      app.register(
        `route:tags.show-category-${filterDasherized}`,
        TagShowRoute.extend({ navMode: filter })
      );
      app.register(
        `route:tags.show-category-none-${filterDasherized}`,
        TagShowRoute.extend({ navMode: filter, noSubcategories: true })
      );
      app.register(
        `route:tags.show-category-all-${filterDasherized}`,
        TagShowRoute.extend({ navMode: filter, noSubcategories: false })
      );
    });
  },
};
