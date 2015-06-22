import ModalFunctionality from 'discourse/mixins/modal-functionality';
import DiscourseController from 'discourse/controllers/controller';
import showModal from 'discourse/lib/show-modal';

// This is happening outside of the app via popup
const AuthErrors =
  ['requires_invite', 'awaiting_approval', 'awaiting_confirmation', 'admin_not_allowed_from_ip_address',
   'not_allowed_from_ip_address'];

export default DiscourseController.extend(ModalFunctionality, {
  needs: ['modal', 'createAccount', 'forgotPassword', 'application'],
  authenticate: null,
  loggingIn: false,
  loggedIn: false,

  canLoginLocal: Discourse.computed.setting('enable_local_logins'),
  loginRequired: Em.computed.alias('controllers.application.loginRequired'),

  resetForm: function() {
    this.set('authenticate', null);
    this.set('loggingIn', false);
    this.set('loggedIn', false);
  },

  /**
   Determines whether at least one login button is enabled
  **/
  hasAtLeastOneLoginButton: function() {
    return Em.get("Discourse.LoginMethod.all").length > 0;
  }.property("Discourse.LoginMethod.all.@each"),

  loginButtonText: function() {
    return this.get('loggingIn') ? I18n.t('login.logging_in') : I18n.t('login.title');
  }.property('loggingIn'),

  loginDisabled: Em.computed.or('loggingIn', 'loggedIn'),

  showSignupLink: function() {
    return this.get('controllers.application.canSignUp') &&
           !this.get('loggingIn') &&
           this.blank('authenticate');
  }.property('loggingIn', 'authenticate'),

  showSpinner: function() {
    return this.get('loggingIn') || this.get('authenticate');
  }.property('loggingIn', 'authenticate'),

  actions: {
    login: function() {
      var self = this;

      if(this.blank('loginName') || this.blank('loginPassword')){
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
          } else {
            self.flash(result.error, 'error');
          }
        } else {
          self.set('loggedIn', true);
          // Trigger the browser's password manager using the hidden static login form:
          var $hidden_login_form = $('#hidden-login-form');
          var destinationUrl = $.cookie('destination_url');
          var shouldRedirectToUrl = self.session.get("shouldRedirectToUrl");
          $hidden_login_form.find('input[name=username]').val(self.get('loginName'));
          $hidden_login_form.find('input[name=password]').val(self.get('loginPassword'));
          if (self.get('loginRequired') && destinationUrl) {
            // redirect client to the original URL
            $.cookie('destination_url', null);
            $hidden_login_form.find('input[name=redirect]').val(destinationUrl);
          } else if (shouldRedirectToUrl) {
            self.session.set("shouldRedirectToUrl", null);
            $hidden_login_form.find('input[name=redirect]').val(shouldRedirectToUrl);
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
    },

    externalLogin: function(loginMethod){
      var name = loginMethod.get("name");
      var customLogin = loginMethod.get("customLogin");

      if(customLogin){
        customLogin();
      } else {
        this.set('authenticate', name);
        var left = this.get('lastX') - 400;
        var top = this.get('lastY') - 200;

        var height = loginMethod.get("frameHeight") || 400;
        var width = loginMethod.get("frameWidth") || 800;
        var w = window.open(Discourse.getURL("/auth/" + name), "_blank",
            "menubar=no,status=no,height=" + height + ",width=" + width +  ",left=" + left + ",top=" + top);
        var self = this;
        var timer = setInterval(function() {
          if(!w || w.closed) {
            clearInterval(timer);
            self.set('authenticate', null);
          }
        }, 1000);
      }
    },

    createAccount: function() {
      var createAccountController = this.get('controllers.createAccount');
      if (createAccountController) {
        createAccountController.resetForm();
        var loginName = this.get('loginName');
        if (loginName && loginName.indexOf('@') > 0) {
          createAccountController.set("accountEmail", loginName);
        } else {
          createAccountController.set("accountUsername", loginName);
        }
      }
      this.send('showCreateAccount');
    },

    forgotPassword: function() {
      var forgotPasswordController = this.get('controllers.forgotPassword');
      if (forgotPasswordController) { forgotPasswordController.set("accountEmailOrUsername", this.get("loginName")); }
      this.send("showForgotPassword");
    }
  },

  authMessage: (function() {
    if (this.blank('authenticate')) return "";
    var method = Discourse.get('LoginMethod.all').findProperty("name", this.get("authenticate"));
    if(method){
      return method.get('message');
    }
  }).property('authenticate'),

  authenticationComplete: function(options) {

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
      if (window.location.pathname === Discourse.getURL('/login')) {
        window.location.pathname = Discourse.getURL('/');
      } else {
        window.location.reload();
      }
      return;
    }

    var createAccountController = this.get('controllers.createAccount');
    createAccountController.setProperties({
      accountEmail: options.email,
      accountUsername: options.username,
      accountName: options.name,
      authOptions: Em.Object.create(options)
    });
    showModal('createAccount');
  }

});
