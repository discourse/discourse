import { mapRoutes } from "discourse/mapping-router";

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(container, app) {
    app.unregister("router:main");
    app.register("router:main", mapRoutes());

    // HACK to fix: https://github.com/emberjs/ember.js/issues/10310
    const originalBuildInstance =
      originalBuildInstance || Ember.Application.prototype.buildInstance;
    Ember.Application.prototype.buildInstance = function() {
      this.buildRegistry();
      return originalBuildInstance.apply(this);
    };
  }
};
