import DiscoveryListController from "discourse/controllers/discovery/list";
import { buildTagRoute } from "discourse/routes/tag/show";

// Runs when the bundle holding the tag routes loads.
export default function setupTagRoutes(app) {
    app.register("route:tags.show-category", buildTagRoute());
    app.register("controller:tags.show-category", DiscoveryListController);
    app.register(
      "route:tags.show-category-none",
      buildTagRoute({
        noSubcategories: true,
      })
    );
    app.register("controller:tags.show-category-none", DiscoveryListController);
    app.register(
      "route:tags.show-category-all",
      buildTagRoute({
        noSubcategories: false,
      })
    );
    app.register("controller:tags.show-category-all", DiscoveryListController);

    // untagged category routes (no tag selected, shows category with tag=none)
    app.register("route:tags.untagged-category", buildTagRoute());
    app.register("controller:tags.untagged-category", DiscoveryListController);
    app.register(
      "route:tags.untagged-category-all",
      buildTagRoute({ noSubcategories: false })
    );
    app.register(
      "controller:tags.untagged-category-all",
      DiscoveryListController
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
        `controller:tag.show-${filterDasherized}`,
        DiscoveryListController
      );
      app.register(
        `route:tags.show-category-${filterDasherized}`,
        buildTagRoute({ navMode: filter })
      );
      app.register(
        `controller:tags.show-category-${filterDasherized}`,
        DiscoveryListController
      );
      app.register(
        `route:tags.show-category-none-${filterDasherized}`,
        buildTagRoute({ navMode: filter, noSubcategories: true })
      );
      app.register(
        `controller:tags.show-category-none-${filterDasherized}`,
        DiscoveryListController
      );
      app.register(
        `route:tags.show-category-all-${filterDasherized}`,
        buildTagRoute({ navMode: filter, noSubcategories: false })
      );
      app.register(
        `controller:tags.show-category-all-${filterDasherized}`,
        DiscoveryListController
      );

      // category filter routes with no tag selected (tag=none)
      app.register(
        `route:tags.untagged-category-${filterDasherized}`,
        buildTagRoute({ navMode: filter })
      );
      app.register(
        `controller:tags.untagged-category-${filterDasherized}`,
        DiscoveryListController
      );
      app.register(
        `route:tags.untagged-category-all-${filterDasherized}`,
        buildTagRoute({ navMode: filter, noSubcategories: false })
      );
      app.register(
        `controller:tags.untagged-category-all-${filterDasherized}`,
        DiscoveryListController
      );
    });
}
