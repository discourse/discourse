export default Ember.Controller.extend({
  adminRoutes: function() {
    return this.get('model').map(p => {
      if (p.get('enabled')) {
        return p.admin_route;
      }
    }).compact();
  }.property()
});
