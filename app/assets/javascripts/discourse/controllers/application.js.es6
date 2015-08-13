export default Ember.Controller.extend({
  showTop: true,
  showFooter: false,
  styleCategory: null,

  canSignUp: function() {
    return !Discourse.SiteSettings.invite_only &&
           Discourse.SiteSettings.allow_new_registrations &&
           !Discourse.SiteSettings.enable_sso;
  }.property(),

  loginRequired: function() {
    return Discourse.SiteSettings.login_required && !Discourse.User.current();
  }.property()

});
