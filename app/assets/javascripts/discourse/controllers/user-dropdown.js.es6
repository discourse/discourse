export default Ember.ArrayController.extend({
  showAdminLinks: Em.computed.alias("currentUser.staff"),

  allowAnon: function(){
    return Discourse.SiteSettings.allow_anonymous_posting &&
      Discourse.User.currentProp("trust_level") >= Discourse.SiteSettings.anonymous_posting_min_trust_level;
  }.property(),

  isAnon: function(){
    return Discourse.User.currentProp("is_anonymous");
  }.property(),

  actions: {
    logout() {
      Discourse.logout();
      return false;
    },
    toggleAnon() {
      Discourse.ajax("/users/toggle-anon", {method: 'POST'}).then(function(){
        window.location.reload();
      });
    }
  }
});
