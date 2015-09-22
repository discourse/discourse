export default Ember.ArrayController.extend({

  adminRoutes: function() {
    return this.get('model').map(function(p) {
        if (p.get('enabled')) {
          return p.admin_route;
        }
    }).compact();
  }.property()
});
