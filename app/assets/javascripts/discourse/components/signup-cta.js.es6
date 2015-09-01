export default Ember.Component.extend({
  action: "showCreateAccount",

  actions: {
    neverShow() {
      this.keyValueStore.setItem('anon-cta-never', 't');
      this.session.set('showSignupCta', false);
    },
    hideForSession() {
      this.session.set('hideSignupCta', true);
      this.keyValueStore.setItem('anon-cta-hidden', new Date().getTime());
      Em.run.later(() =>
        this.session.set('showSignupCta', false),
      20 * 1000);
    },
    showCreateAccount() {
      this.sendAction();
    }
  },

  signupMethodsTranslated: function() {
    const methods = Ember.get('Discourse.LoginMethod.all');
    const loginWithEmail = this.siteSettings.enable_local_logins;
    if (this.siteSettings.enable_sso) {
      return I18n.t('signup_cta.methods.sso');
    } else if (methods.length === 0) {
      if (loginWithEmail) {
        return I18n.t('signup_cta.methods.only_email');
      } else {
        return I18n.t('signup_cta.methods.unknown');
      }
    } else if (methods.length === 1) {
      let providerName = methods[0].name.capitalize();
      if (providerName === "Google_oauth2") {
        providerName = "Google";
      }
      if (loginWithEmail) {
        return I18n.t('signup_cta.methods.one_and_email', {provider: providerName});
      } else {
        return I18n.t('signup_cta.methods.only_other', {provider: providerName});
      }
    } else {
      if (loginWithEmail) {
        return I18n.t('signup_cta.methods.multiple', {count: methods.length});
      } else {
        return I18n.t('signup_cta.methods.multiple_no_email', {count: methods.length});
      }
    }
  }.property(),

  _turnOffIfHidden: function() {
    if (this.session.get('hideSignupCta')) {
      this.session.set('showSignupCta', false);
    }
  }.on('willDestroyElement')
});
