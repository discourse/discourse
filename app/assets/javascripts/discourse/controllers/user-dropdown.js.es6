export default Ember.ArrayController.extend({
  showAdminLinks: Em.computed.alias("currentUser.staff"),

  allowAnon: function(){
    return this.siteSettings.allow_anonymous_posting &&
      (this.get("currentUser.trust_level") >= this.siteSettings.anonymous_posting_min_trust_level ||
       this.get("isAnon"));
  }.property(),

  isAnon: function(){
    return this.get("currentUser.is_anonymous");
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
