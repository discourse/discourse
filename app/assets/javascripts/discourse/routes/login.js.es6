export default Discourse.Route.extend({
  beforeModel: function() {
    if (!Discourse.SiteSettings.login_required) {
      this.replaceWith('discovery.latest').then(function(e) {
        Ember.run.next(function() {
          e.send('showLogin');
        });
      });
    }
  }
});
