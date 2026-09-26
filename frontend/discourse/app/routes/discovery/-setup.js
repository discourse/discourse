import { dasherize } from "@ember/string";
import DiscoveryListController from "discourse/controllers/discovery/list";
import Site from "discourse/models/site";
import buildCategoryRoute from "discourse/routes/build-category-route";
import buildTopicRoute from "discourse/routes/build-topic-route";

// Runs when the discovery bundle loads, before the router resolves its routes.
export default function setupDiscoveryRoutes(app) {

  app.register(
    "route:discovery.category",
    buildCategoryRoute({ filter: "default" })
  );
  app.register("controller:discovery.category", DiscoveryListController);
  app.register(
    "route:discovery.category-none",
    buildCategoryRoute({ filter: "default", no_subcategories: true })
  );
  app.register("controller:discovery.category-none", DiscoveryListController);
  app.register(
    "route:discovery.category-all",
    buildCategoryRoute({ filter: "default", no_subcategories: false })
  );
  app.register("controller:discovery.category-all", DiscoveryListController);

  const site = Site.current();
  site.get("filters").forEach((filter) => {
    const filterDasherized = dasherize(filter);

    app.register(
      `route:discovery.${filterDasherized}`,
      buildTopicRoute(filter)
    );
    app.register(
      `controller:discovery.${filterDasherized}`,
      DiscoveryListController
    );

    app.register(
      `route:discovery.${filterDasherized}-category`,
      buildCategoryRoute({ filter })
    );
    app.register(
      `controller:discovery.${filterDasherized}-category`,
      DiscoveryListController
    );
    app.register(
      `route:discovery.${filterDasherized}-category-none`,
      buildCategoryRoute({ filter, no_subcategories: true })
    );
    app.register(
      `controller:discovery.${filterDasherized}-category-none`,
      DiscoveryListController
    );
  });
}
