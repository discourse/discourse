import { mapRoutes } from "discourse/mapping-router";

export default {
  after: "inject-discourse-objects",

  initialize(app) {
    this.routerClass = mapRoutes();
    app.register("router:main", this.routerClass);
  },

  teardown() {
    this.routerClass.dslCallbacks.length = 0;
  },
};
