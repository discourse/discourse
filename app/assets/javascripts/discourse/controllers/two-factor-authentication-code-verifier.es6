import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend(ModalFunctionality, {
  needs: ['modal', 'application'],
  authenticate: null,
  loggingIn: false,
  loggedIn: false,

  loginRequired: Em.computed.alias('controllers.application.loginRequired'),

  resetForm() {
    this.set('authenticate', null);
    this.set('loggingIn', false);
    this.set('loggedIn', false);
  },

  loginButtonText: function() {
    return this.get('loggingIn') ? I18n.t('login.logging_in') : I18n.t('login.title');
  }.property('loggingIn'),

  actions: {
    verify() {
      var self = this;

      if (this.blank('twoFactorAuthenticationCode')) {
        self.flash(I18n.t('login.blank_code'), 'error');
        return;
      }

      this.set('loggingIn', true);

      Discourse.ajax("/session/verify_two_factor_authentication_code", {
        data: { code: this.get('twoFactorAuthenticationCode') },
        type: 'POST'
      }).then(function(result) {
        // Successful login
        if (result.error) {
          self.set('loggingIn', false);
          self.flash(result.error, 'error');
        } else {
          self.set('loggedIn', true);
          var $hidden_login_form = $('#hidden-login-form');
          var destinationUrl = $.cookie('destination_url');
          if (self.get('loginRequired') && destinationUrl) {
            // redirect client to the original URL
            $.cookie('destination_url', null);
            $hidden_login_form.find('input[name=redirect]').val(destinationUrl);
          } else {
            $hidden_login_form.find('input[name=redirect]').val(window.location.href);
          }
          $hidden_login_form.submit();
        }

      }, function() {
        // Failed to login
        self.flash(I18n.t('login.error'), 'error');
        self.set('loggingIn', false);
      });

      return false;
    }
  }

});
