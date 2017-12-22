import { default as computed } from 'ember-addons/ember-computed-decorators';
import DiscourseURL from 'discourse/lib/url';
import { userPath } from 'discourse/lib/url';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({

  loading: false,
  password: null,
  secondFactorImage: null,
  secondFactorKey: null,
  showSecondFactorKey: false,

  errorMessage: null,
  newUsername: null,

  @computed('secondFactorImage','secondFactorKey')
  loaded(secondFactorImage, secondFactorKey) {
    return secondFactorImage && secondFactorKey;
  },

  @computed('loading')
  submitButtonText(loading) {
    if (loading) return I18n.t('loading');
    return I18n.t('submit');
  },

  toggleSecondFactor(enable) {
    if(!this.get('second_factor_token')) {
      return;
    }
    this.set('loading', true);
    this.get('content').toggleSecondFactor(this.get('second_factor_token'), enable).then((resp) => {
      if(resp.error) {
        this.set('errorMessage',resp.error);
        return;
      }
      this.set('errorMessage',null);
      DiscourseURL.redirectTo(userPath(this.get('content').username.toLowerCase() + "/preferences"));
    })
      .catch(popupAjaxError)
      .finally(() => this.set('loading', false));
  },

  actions: {
    confirmPassword() {
      if(!this.get('password')) {
        return;
      }
      this.set('loading', true);
      this.get('content').loadSecondFactorCodes(this.get('password')).then((resp) => {
        if(resp.error) {
          this.set('errorMessage',resp.error);
          return;
        }
        this.set('errorMessage',null);
        this.set('secondFactorKey', resp.key);
        this.set('secondFactorImage', resp.qr);
      }).catch(popupAjaxError)
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
