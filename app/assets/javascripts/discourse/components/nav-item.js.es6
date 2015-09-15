/* You might be looking for navigation-item. */

import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['active'],

  @computed()
  router() {
    return this.container.lookup('router:main');
  },

  @computed("path")
  fullPath(path) {
    return Discourse.getURL(path);
  },

  @computed("route", "router.url")
  active(route) {
    if (!route) { return; }

    const routeParam = this.get('routeParam'),
          router = this.get('router');

    return routeParam ? router.isActive(route, routeParam) : router.isActive(route);
  }
});
