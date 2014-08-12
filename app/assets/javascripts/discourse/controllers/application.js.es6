export default Ember.Controller.extend({
  styleCategory: null,

  canSignUp: function() {
    return !Discourse.SiteSettings.invite_only &&
           Discourse.SiteSettings.allow_new_registrations &&
           !Discourse.SiteSettings.enable_sso;
  }.property(),
});
