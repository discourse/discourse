import Application from "@ember/application";
import { isLegacyEmber } from "discourse-common/config/environment";
import { registerRouter, teardownRouter } from "discourse/mapping-router";

let originalBuildInstance;

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(container, app) {
    let router = registerRouter(app);
    container.registry.register("router:main", router);

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

  teardown(container) {
    teardownRouter(container);
  },
};
