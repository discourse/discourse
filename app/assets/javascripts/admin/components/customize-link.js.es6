export default Ember.Component.extend({
  router: function() {
    return this.container.lookup('router:main');
  }.property(),

  active: function() {
    const id = this.get('customization.id');
    return this.get('router.url').indexOf(`/customize/css_html/${id}/css`) !== -1;
  }.property('router.url', 'customization.id')
});
