import { mapRoutes } from 'discourse/mapping-router';

export default {
  name: "map-routes",
  after: 'inject-discourse-objects',

  initialize(container, app) {
    app.register('router:main', mapRoutes());

    // HACK to fix: https://github.com/emberjs/ember.js/issues/10310
    const originalBuildInstance = originalBuildInstance || Ember.Application.prototype.buildInstance;
    Ember.Application.prototype.buildInstance = function() {
      const registry = this.buildRegistry();
      if (Ember.VERSION[0] === "1") {
        this.registry = registry;
      }
      return originalBuildInstance.apply(this);
    };
  }
};
