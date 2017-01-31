import { default as computed } from 'ember-addons/ember-computed-decorators';
import getUrl from 'discourse-common/lib/get-url';
import { ajax } from 'discourse/lib/ajax';
import PasswordValidation from "discourse/mixins/password-validation";

export default Ember.Controller.extend(PasswordValidation, {
  isDeveloper: Ember.computed.alias('model.is_developer'),
  passwordRequired: true,
  errorMessage: null,
  successMessage: null,
  requiresApproval: false,

  @computed()
  continueButtonText() {
    return I18n.t('password_reset.continue', {site_name: Discourse.SiteSettings.title});
  },

  @computed()
  lockImageUrl() {
    return getUrl('/images/lock.svg');
  },

  actions: {
    submit() {
      const self = this;
      ajax({
        url: `/users/password-reset/${this.get('model.token')}.json`,
        type: 'PUT',
        data: {
          password: this.get('accountPassword')
        }
      }).then(result => {
        if (result.success) {
          self.set('successMessage', result.message);
          self.set('redirectTo', result.redirect_to);
          if (result.requires_approval) {
            self.set('requiresApproval', true);
          }
        } else {
          if (result.errors && result.errors.password && result.errors.password.length > 0) {
            self.get('rejectedPasswords').pushObject(self.get('accountPassword'));
            self.get('rejectedPasswordsMessages').set(self.get('accountPassword'), result.errors.password[0]);
          }
          if (result.message) {
            self.set('errorMessage', result.message);
          }
        }
      }).catch(response => {
        throw response;
      });
    },

    done() {
      window.location.pathname = this.get('redirectTo') || Discourse.getURL("/");
    }
  }
});
