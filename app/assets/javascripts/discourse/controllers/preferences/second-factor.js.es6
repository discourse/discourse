import { default as computed } from 'ember-addons/ember-computed-decorators';
import { default as DiscourseURL, userPath } from 'discourse/lib/url';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  loading: false,
  password: null,
  secondFactorImage: null,
  secondFactorKey: null,
  showSecondFactorKey: false,
  errorMessage: null,
  newUsername: null,

  loaded: Ember.computed.and('secondFactorImage', 'secondFactorKey'),

  @computed('loading')
  submitButtonText(loading) {
    return loading ? 'loading' : 'submit';
  },

  toggleSecondFactor(enable) {
    if (!this.get('second_factor_token')) return;
    this.set('loading', true);

    this.get('content').toggleSecondFactor(this.get('second_factor_token'), enable)
      .then(response => {
        if (response.error) {
          this.set('errorMessage', response.error);
          return;
        }

        this.set('errorMessage',null);
        DiscourseURL.redirectTo(userPath(`${this.get('content').username.toLowerCase()}/preferences`));
      })
      .catch(popupAjaxError)
      .finally(() => this.set('loading', false));
  },

  actions: {
    confirmPassword() {
      if (!this.get('password')) return;
      this.set('loading', true);

      this.get('content').loadSecondFactorCodes(this.get('password'))
        .then(response => {
          if(response.error) {
            this.set('errorMessage', response.error);
            return;
          }

          this.setProperties({
            errorMessage: null,
            secondFactorKey: response.key,
            secondFactorImage: response.qr,
          });
        })
        .catch(popupAjaxError)
        .finally(() => this.set('loading', false));
    },

    showSecondFactorKey() {
      this.set('showSecondFactorKey', true);
    },

    enableSecondFactor() {
      this.toggleSecondFactor(true);
    },

    disableSecondFactor() {
      this.toggleSecondFactor(false);
    }
  }
});
