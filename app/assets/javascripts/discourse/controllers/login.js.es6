import ModalFunctionality from 'discourse/mixins/modal-functionality';
import showModal from 'discourse/lib/show-modal';
import { setting } from 'discourse/lib/computed';
import { findAll } from 'discourse/models/login-method';

// This is happening outside of the app via popup
const AuthErrors =
  ['requires_invite', 'awaiting_approval', 'awaiting_confirmation', 'admin_not_allowed_from_ip_address',
   'not_allowed_from_ip_address'];

export default Ember.Controller.extend(ModalFunctionality, {
  needs: ['modal', 'createAccount', 'forgotPassword', 'application'],
  authenticate: null,
  loggingIn: false,
  loggedIn: false,

  canLoginLocal: setting('enable_local_logins'),
  loginRequired: Em.computed.alias('controllers.application.loginRequired'),

  resetForm: function() {
    this.set('authenticate', null);
    this.set('loggingIn', false);
    this.set('loggedIn', false);
  },

  // Determines whether at least one login button is enabled
  hasAtLeastOneLoginButton: function() {
    return findAll(this.siteSettings).length > 0;
  }.property(),

  loginButtonText: function() {
    return this.get('loggingIn') ? I18n.t('login.logging_in') : I18n.t('login.title');
  }.property('loggingIn'),

  loginDisabled: Em.computed.or('loggingIn', 'loggedIn'),

  showSignupLink: function() {
    return this.get('controllers.application.canSignUp') &&
           !this.get('loggingIn') &&
           Ember.isEmpty(this.get('authenticate'));
  }.property('loggingIn', 'authenticate'),

  showSpinner: function() {
    return this.get('loggingIn') || this.get('authenticate');
  }.property('loggingIn', 'authenticate'),

  actions: {
    login: function() {
      const self = this;

      if(Ember.isEmpty(this.get('loginName')) || Ember.isEmpty(this.get('loginPassword'))){
        self.flash(I18n.t('login.blank_username_or_password'), 'error');
        return;
      }

      this.set('loggingIn', true);

      Discourse.ajax("/session", {
        data: { login: this.get('loginName'), password: this.get('loginPassword') },
        type: 'POST'
      }).then(function (result) {
        // Successful login
        if (result.error) {
          self.set('loggingIn', false);
          if( result.reason === 'not_activated' ) {
            self.send('showNotActivated', {
              username: self.get('loginName'),
              sentTo: result.sent_to_email,
              currentEmail: result.current_email
            });
          } else if (result.reason === 'suspended' ) {
            self.send("closeModal");
            bootbox.alert(result.error);
          } else {
            self.flash(result.error, 'error');
          }
        } else {
          self.set('loggedIn', true);
          // Trigger the browser's password manager using the hidden static login form:
          const $hidden_login_form = $('#hidden-login-form');
          const destinationUrl = $.cookie('destination_url');
          const shouldRedirectToUrl = self.session.get("shouldRedirectToUrl");
          const ssoDestinationUrl = $.cookie('sso_destination_url');
          $hidden_login_form.find('input[name=username]').val(self.get('loginName'));
          $hidden_login_form.find('input[name=password]').val(self.get('loginPassword'));

          if (ssoDestinationUrl) {
            $.cookie('sso_destination_url', null);
            window.location.assign(ssoDestinationUrl);
            return;
          } else if (destinationUrl) {
            // redirect client to the original URL
            $.cookie('destination_url', null);
            $hidden_login_form.find('input[name=redirect]').val(destinationUrl);
          } else if (shouldRedirectToUrl) {
            self.session.set("shouldRedirectToUrl", null);
            $hidden_login_form.find('input[name=redirect]').val(shouldRedirectToUrl);
          } else {
            $hidden_login_form.find('input[name=redirect]').val(window.location.href);
          }

          if (navigator.userAgent.match(/(iPad|iPhone|iPod)/g) && navigator.userAgent.match(/Safari/g)) {
            // In case of Safari on iOS do not submit hidden login form
            window.location.href = $hidden_login_form.find('input[name=redirect]').val();
          } else {
            $hidden_login_form.submit();
          }
          return;
        }

      }, function(e) {
        // Failed to login
        if (e.jqXHR && e.jqXHR.status === 429) {
          self.flash(I18n.t('login.rate_limit'), 'error');
        } else {
          self.flash(I18n.t('login.error'), 'error');
        }
        self.set('loggingIn', false);
      });

      return false;
    },

    externalLogin: function(loginMethod){
      const name = loginMethod.get("name");
      const customLogin = loginMethod.get("customLogin");

      if(customLogin){
        customLogin();
      } else {
        const authUrl = loginMethod.get('customUrl') || Discourse.getURL("/auth/" + name);
        if (loginMethod.get("fullScreenLogin")) {
          window.location = authUrl;
        } else {
          this.set('authenticate', name);
          const left = this.get('lastX') - 400;
          const top = this.get('lastY') - 200;

          const height = loginMethod.get("frameHeight") || 400;
          const width = loginMethod.get("frameWidth") || 800;
          const w = window.open(authUrl, "_blank",
              "menubar=no,status=no,height=" + height + ",width=" + width +  ",left=" + left + ",top=" + top);
          const self = this;
          const timer = setInterval(function() {
            if(!w || w.closed) {
              clearInterval(timer);
              self.set('authenticate', null);
            }
          }, 1000);
        }
      }
    },

    createAccount: function() {
      const createAccountController = this.get('controllers.createAccount');
      if (createAccountController) {
        createAccountController.resetForm();
        const loginName = this.get('loginName');
        if (loginName && loginName.indexOf('@') > 0) {
          createAccountController.set("accountEmail", loginName);
        } else {
          createAccountController.set("accountUsername", loginName);
        }
      }
      this.send('showCreateAccount');
    },

    forgotPassword: function() {
      const forgotPasswordController = this.get('controllers.forgotPassword');
      if (forgotPasswordController) { forgotPasswordController.set("accountEmailOrUsername", this.get("loginName")); }
      this.send("showForgotPassword");
    }
  },

  authMessage: (function() {
    if (Ember.isEmpty(this.get('authenticate'))) return "";
    const method = findAll(this.siteSettings).findProperty("name", this.get("authenticate"));
    if(method){
      return method.get('message');
    }
  }).property('authenticate'),

  authenticationComplete(options) {

    const self = this;
    function loginError(errorMsg, className) {
      showModal('login');
      Ember.run.next(function() {
        self.flash(errorMsg, className || 'success');
        self.set('authenticate', null);
      });
    }

    for (let i=0; i<AuthErrors.length; i++) {
      const cond = AuthErrors[i];
      if (options[cond]) {
        return loginError(I18n.t("login." + cond));
      }
    }

    if (options.suspended) {
      return loginError(options.suspended_message, 'error');
    }

    // Reload the page if we're authenticated
    if (options.authenticated) {
      const destinationUrl = $.cookie('destination_url');
      const shouldRedirectToUrl = self.session.get("shouldRedirectToUrl");
      if (self.get('loginRequired') && destinationUrl) {
        // redirect client to the original URL
        $.cookie('destination_url', null);
        window.location.href = destinationUrl;
      } else if (shouldRedirectToUrl) {
        self.session.set("shouldRedirectToUrl", null);
        window.location.href = shouldRedirectToUrl;
      } else if (window.location.pathname === Discourse.getURL('/login')) {
        window.location.pathname = Discourse.getURL('/');
      } else {
        window.location.reload();
      }
      return;
    }

    const createAccountController = this.get('controllers.createAccount');
    createAccountController.setProperties({
      accountEmail: options.email,
      accountUsername: options.username,
      accountName: options.name,
      authOptions: Ember.Object.create(options)
    });
    showModal('createAccount');
  }

});
