import { mapRoutes } from "discourse/mapping-router";

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(_, app) {
    this.routerClass = mapRoutes();
    app.register("router:main", this.routerClass);
  },

  teardown() {
    this.routerClass.dslCallbacks.length = 0;
  },
};
