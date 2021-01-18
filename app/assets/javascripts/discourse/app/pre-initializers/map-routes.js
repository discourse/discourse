import Application from "@ember/application";
import Ember from "ember";
import { registerRouter } from "discourse/mapping-router";

let originalBuildInstance;

export default {
  name: "map-routes",
  after: "inject-discourse-objects",

  initialize(container, app) {
    let router = registerRouter(app);
    container.registry.register("router:main", router);

    // TODO: Remove this once we've upgraded Ember everywhere
    if (Ember.VERSION.startsWith("3.12")) {
      // HACK to fix: https://github.com/emberjs/ember.js/issues/10310
      originalBuildInstance =
        originalBuildInstance || Application.prototype.buildInstance;

      Application.prototype.buildInstance = function () {
        this.buildRegistry();
        return originalBuildInstance.apply(this);
      };
    }
  },
};
