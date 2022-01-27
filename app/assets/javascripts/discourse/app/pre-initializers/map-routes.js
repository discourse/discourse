import Application from "@ember/application";
import { isLegacyEmber } from "discourse-common/config/environment";
import { registerRouter, teardownRouter } from "discourse/mapping-router";

let originalBuildInstance;

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(container, app) {
    let routerClass = registerRouter(app);
    container.registry.register("router:main", routerClass);
    this.routerClass = routerClass;

    if (isLegacyEmber()) {
      // HACK to fix: https://github.com/emberjs/ember.js/issues/10310
      originalBuildInstance =
        originalBuildInstance || Application.prototype.buildInstance;

      Application.prototype.buildInstance = function () {
        this.buildRegistry();
        return originalBuildInstance.apply(this);
      };
    }
  },

  teardown() {
    teardownRouter(this.routerClass);
  },
};
