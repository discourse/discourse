export default Ember.ObjectController.extend({
  qr: Em.computed.alias('twoFactorAuthenticationData.modules'),
  enabledTwoFactorAuthentication: Em.computed.alias('enabled_two_factor_authentication'),

  appName: function() {
    const data = this.get('twoFactorAuthenticationData.data');
    return data ? data.match(/otpauth:\/\/totp\/(\S+)\?secret=(\S+)/)[1] : null;
  }.property('twoFactorAuthenticationData'),

  secret: function() {
    const data = this.get('twoFactorAuthenticationData.data');
    return data ? data.match(/otpauth:\/\/totp\/(\S+)\?secret=(\S+)/)[2] : null;
  }.property('twoFactorAuthenticationData'),

  savingStatus: function() {
    if (this.get('saving')) {
      return I18n.t('saving');
    } else {
      return I18n.t('save');
    }
  }.property('saving'),

  actions: {
    save() {
      this.setProperties({ saved: false, saving: true });

      const self = this;
      Discourse.ajax(this.get('model.path') + '/preferences/two-factor-authentication', {
        type: 'PUT',
        data: {
          secret: self.get('secret'),
          code: self.get('code')
        }
      }).then(function() {
        self.setProperties({
          saved: true,
          saving: false,
          enabledTwoFactorAuthentication: true
        });
      }).catch(function() {
        self.set('saving', false);
        bootbox.alert(I18n.t('user.two_factor_authentication.configuration.incorret_code'));
      });
    },

    revoke() {
      const self = this;
      Discourse.ajax(this.get('model.path') + '/preferences/revoke-two-factor-authentication', {
        type: 'PUT',
        data: { revoke: true }
      }).then(function() {
        self.setProperties({
          enabledTwoFactorAuthentication: false
        });
      }).catch(function() {
        bootbox.alert(I18n.t('generic_error'));
      });
    }

  }
});
