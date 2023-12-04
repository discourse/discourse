import CompatRoute from "ember-polaris-routing/route/compat";
import Plugins from "discourse-plugins-v2/route-maps/app";

export default {
  initialize(owner) {
    for (const {
      name,
      module: { default: callback },
    } of Plugins) {
      const [prefix] = name.split("/");

      callback({
        route(routeName, _, RouteClass) {
          owner.register(
            `route:${prefix}/${routeName}`,
            CompatRoute(RouteClass)
          );
        },
      });
    }
  },
};
