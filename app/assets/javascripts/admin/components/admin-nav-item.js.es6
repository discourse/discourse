export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['active'],

  router: function() {
    return this.container.lookup('router:main');
  }.property(),

  active: function() {
    return this.get('router').isActive(this.get('route'));
  }.property('router.url', 'route')
});
