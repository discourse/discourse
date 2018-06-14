import { default as computed } from 'ember-addons/ember-computed-decorators';
import { default as DiscourseURL, userPath } from 'discourse/lib/url';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import { LOGIN_METHODS }  from 'discourse/models/login-method';

export default Ember.Controller.extend({
  loading: false,
  errorMessage: null,


  @computed('loading')
  submitButtonText(loading) {
    return loading ? 'loading' : 'continue';
  },

  @computed('loading')
  enableButtonText(loading) {
    return loading ? 'loading' : 'enable';
  },

  @computed('loading')
  disableButtonText(loading) {
    return loading ? 'loading' : 'disable';
  },

  actions: {
    createSecondFactorBackup() {
      if (!this.get('secondFactorToken')) return;
      const model = this.get('model');
      this.set('loading', true);
      this.get('content').loadSecondFactorBackupCodes(this.get('secondFactorToken'))
        .then(response => {
          if(response.error) {
            this.set('errorMessage', response.error);
            return;
          }

          this.setProperties({
            errorMessage: null,
            secondFactorCodes: response.backup_codes
          });
          model.set('second_factor_backup_enabled', true);
        })
        .catch(popupAjaxError)
        .finally(() => this.set('loading', false));
    },

    disableSecondFactorBackup() {
      if (!this.get('secondFactorToken')) return;
      this.set('loading', true);

      this.get('content').toggleSecondFactor(this.get('secondFactorToken'), false, 2)
        .then(response => {
          if (response.error) {
            this.set('errorMessage', response.error);
            this.set('loading', false);
            return;
          }

          this.set('errorMessage',null);
          DiscourseURL.redirectTo(userPath(`${this.get('content').username.toLowerCase()}/preferences`));
        })
        .catch(error => {
          this.set('loading', false);
          popupAjaxError(error);
        });
    },

    regenerateSecondFactorCodes() {
      if (!this.get('secondFactorToken')) return;
      this.set('loading', true);
      this.get('content').regenerateSecondFactorCodes(this.get('secondFactorToken'))
        .then(response => {
          if(response.error) {
            this.set('errorMessage', response.error);
            return;
          }

          this.setProperties({
            errorMessage: null,
            secondFactorCodes: response.backup_codes
          });
        })
        .catch(popupAjaxError)
        .finally(() => this.set('loading', false));
    }
  }
});
