export default Ember.ArrayController.extend({

  adminRoutes: function() {
    return this.get('model').map(p => p.admin_route).compact();
  }.property()
});
