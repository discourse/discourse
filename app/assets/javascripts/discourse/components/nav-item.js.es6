/* You might be looking for navigation-item. */
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "li",
  classNameBindings: ["active"],
  router: Ember.inject.service(),

  @computed("path")
  fullPath(path) {
    return Discourse.getURL(path);
  },

  @computed("route", "router.currentRoute")
  active(route, currentRoute) {
    if (!route) {
      return;
    }

    const routeParam = this.get("routeParam");
    if (routeParam && currentRoute) {
      return currentRoute.params["filter"] === routeParam;
    }

    return this.get("router").isActive(route);
  }
});
