/**
  This controller supports actions related to flagging

  @class LoginController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.LoginController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  needs: ['modal', 'createAccount'],
  authenticate: null,
  loggingIn: false,

  site: function() {
    return Discourse.Site.current();
  }.property(),

  /**
   Determines whether at least one login button is enabled
  **/
  hasAtLeastOneLoginButton: function() {
    return Em.get("Discourse.LoginMethod.all").length > 0;
  }.property("Discourse.LoginMethod.all.@each"),

  loginButtonText: function() {
    return this.get('loggingIn') ? I18n.t('login.logging_in') : I18n.t('login.title');
  }.property('loggingIn'),

  loginDisabled: function() {
    return this.get('loggingIn') || this.blank('loginName') || this.blank('loginPassword');
  }.property('loginName', 'loginPassword', 'loggingIn'),

  login: function() {
    this.set('loggingIn', true);

    var loginController = this;
    Discourse.ajax("/session", {
      data: { login: this.get('loginName'), password: this.get('loginPassword') },
      type: 'POST'
    }).then(function (result) {
      // Successful login
      if (result.error) {
        loginController.set('loggingIn', false);
        if( result.reason === 'not_activated' ) {
          loginController.send('showNotActivated', {
            username: loginController.get('loginName'),
            sentTo: result.sent_to_email,
            currentEmail: result.current_email
          });
        }
        loginController.flash(result.error, 'error');
      } else {
        // Trigger the browser's password manager using the hidden static login form:
        var $hidden_login_form = $('#hidden-login-form');
        $hidden_login_form.find('input[name=username]').val(loginController.get('loginName'));
        $hidden_login_form.find('input[name=password]').val(loginController.get('loginPassword'));
        $hidden_login_form.find('input[name=redirect]').val(window.location.href);
        $hidden_login_form.submit();
      }

    }, function(result) {
      // Failed to login
      loginController.flash(I18n.t('login.error'), 'error');
      loginController.set('loggingIn', false);
    });

    return false;
  },

  authMessage: (function() {
    if (this.blank('authenticate')) return "";
    var method = Discourse.get('LoginMethod.all').findProperty("name", this.get("authenticate"));
    if(method){
      return method.get('message');
    }
  }).property('authenticate'),

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
      window.open(Discourse.getURL("/auth/" + name), "_blank",
          "menubar=no,status=no,height=" + height + ",width=" + width +  ",left=" + left + ",top=" + top);
    }
  },

  authenticationComplete: function(options) {
    if (options.requires_invite) {
      this.flash(I18n.t('login.requires_invite'), 'success');
      this.set('authenticate', null);
      return;
    }
    if (options.awaiting_approval) {
      this.flash(I18n.t('login.awaiting_approval'), 'success');
      this.set('authenticate', null);
      return;
    }
    if (options.awaiting_activation) {
      this.flash(I18n.t('login.awaiting_confirmation'), 'success');
      this.set('authenticate', null);
      return;
    }
    // Reload the page if we're authenticated
    if (options.authenticated) {
      if (window.location.pathname === '/login') {
        window.location.pathname = '/';
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
    this.send('showCreateAccount');
  }

});
