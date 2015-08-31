/* You might be looking for navigation-item. */

export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['active'],

  router: function() {
    return this.container.lookup('router:main');
  }.property(),

  fullPath: function() {
    return Discourse.getURL(this.get('path'));
  }.property('path'),

  active: function() {
    const route = this.get('route');
    if (!route) { return; }

    const routeParam = this.get('routeParam'),
          router = this.get('router');

    return routeParam ? router.isActive(route, routeParam) : router.isActive(route);
  }.property('router.url', 'route')
});
