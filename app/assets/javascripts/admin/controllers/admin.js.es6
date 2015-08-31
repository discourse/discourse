export default Ember.Controller.extend({
  showBadges: function() {
    return this.get('currentUser.admin') && this.siteSettings.enable_badges;
  }.property()
});
