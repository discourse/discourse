import { default as computed } from 'ember-addons/ember-computed-decorators';
import getUrl from 'discourse-common/lib/get-url';
import DiscourseURL from 'discourse/lib/url';
import { ajax } from 'discourse/lib/ajax';
import PasswordValidation from "discourse/mixins/password-validation";
import UsernameValidation from "discourse/mixins/username-validation";
import { findAll as findLoginMethods }  from 'discourse/models/login-method';

export default Ember.Controller.extend(PasswordValidation, UsernameValidation, {
  invitedBy: Ember.computed.alias('model.invited_by'),
  email: Ember.computed.alias('model.email'),
  accountUsername: Ember.computed.alias('model.username'),
  passwordRequired: Ember.computed.notEmpty('accountPassword'),
  successMessage: null,
  errorMessage: null,
  inviteImageUrl: getUrl('/images/envelope.svg'),

  @computed
  welcomeTitle() {
    return I18n.t('invites.welcome_to', {site_name: this.siteSettings.title});
  },

  @computed('email')
  yourEmailMessage(email) {
    return I18n.t('invites.your_email', {email: email});
  },

  @computed
  externalAuthsEnabled() {
    return findLoginMethods(this.siteSettings, this.capabilities, this.site.isMobileDevice).length > 0;
  },

  @computed('usernameValidation.failed', 'passwordValidation.failed')
  submitDisabled(usernameFailed, passwordFailed) {
    return usernameFailed || passwordFailed;
  },

  actions: {
    submit() {
      ajax({
        url: `/invites/show/${this.get('model.token')}.json`,
        type: 'PUT',
        data: {
          username: this.get('accountUsername'),
          password: this.get('accountPassword')
        }
      }).then(result => {
        if (result.success) {
          this.set('successMessage', result.message || I18n.t('invites.success'));
          this.set('redirectTo', result.redirect_to);
          DiscourseURL.redirectTo(result.redirect_to || '/');
        } else {
          if (result.errors && result.errors.password && result.errors.password.length > 0) {
            this.get('rejectedPasswords').pushObject(this.get('accountPassword'));
            this.get('rejectedPasswordsMessages').set(this.get('accountPassword'), result.errors.password[0]);
          }
          if (result.message) {
            this.set('errorMessage', result.message);
          }
        }
      }).catch(response => {
        throw response;
      });
    }
  }
});
