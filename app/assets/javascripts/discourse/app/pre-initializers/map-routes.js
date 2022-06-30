import { registerRouter, teardownRouter } from "discourse/mapping-router";

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(container, app) {
    let routerClass = registerRouter(app);
    container.registry.register("router:main", routerClass);
    this.routerClass = routerClass;
  },

  teardown() {
    teardownRouter(this.routerClass);
  },
};
