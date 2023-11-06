import { dasherize } from "@ember/string";
import Site from "discourse/models/site";
import buildCategoryRoute from "discourse/routes/build-category-route";
import buildTopicRoute from "discourse/routes/build-topic-route";
import { buildTagRoute } from "discourse/routes/tag-show";

export default {
  after: "inject-discourse-objects",

  initialize(app) {
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

    app.register("route:tags.show-category", buildTagRoute());
    app.register(
      "route:tags.show-category-none",
      buildTagRoute({
        noSubcategories: true,
      })
    );
    app.register(
      "route:tags.show-category-all",
      buildTagRoute({
        noSubcategories: false,
      })
    );

    site.get("filters").forEach(function (filter) {
      const filterDasherized = dasherize(filter);

      app.register(
        `route:tag.show-${filterDasherized}`,
        buildTagRoute({
          navMode: filter,
        })
      );
      app.register(
        `route:tags.show-category-${filterDasherized}`,
        buildTagRoute({ navMode: filter })
      );
      app.register(
        `route:tags.show-category-none-${filterDasherized}`,
        buildTagRoute({ navMode: filter, noSubcategories: true })
      );
      app.register(
        `route:tags.show-category-all-${filterDasherized}`,
        buildTagRoute({ navMode: filter, noSubcategories: false })
      );
    });
  },
};
