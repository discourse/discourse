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
    return Discourse.Site.instance();
  }.property(),


  /**
   Determines whether at least one login button is enabled
  **/
  hasAtLeastOneLoginButton: function() {
    return Discourse.SiteSettings.enable_google_logins ||
           Discourse.SiteSettings.enable_facebook_logins ||
           Discourse.SiteSettings.enable_cas_logins ||
           Discourse.SiteSettings.enable_twitter_logins ||
           Discourse.SiteSettings.enable_yahoo_logins ||
           Discourse.SiteSettings.enable_github_logins ||
           Discourse.SiteSettings.enable_persona_logins;
  }.property(),

  loginButtonText: function() {
    return this.get('loggingIn') ? Em.String.i18n('login.logging_in') : Em.String.i18n('login.title');
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
        $hidden_login_form.find('input[name=authenticity_token]').val($('meta[name=csrf-token]').attr('content'));
        $hidden_login_form.submit();
      }

    }, function(result) {
      // Failed to login
      loginController.flash(Em.String.i18n('login.error'), 'error');
      loginController.set('loggingIn', false);
    })

    return false;
  },

  authMessage: (function() {
    if (this.blank('authenticate')) return "";
    return Em.String.i18n("login." + (this.get('authenticate')) + ".message");
  }).property('authenticate'),

  twitterLogin: function() {
    this.set('authenticate', 'twitter');
    var left = this.get('lastX') - 400;
    var top = this.get('lastY') - 200;
    return window.open(Discourse.getURL("/auth/twitter"), "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
  },

  facebookLogin: function() {
    this.set('authenticate', 'facebook');
    var left = this.get('lastX') - 400;
    var top = this.get('lastY') - 200;
    return window.open(Discourse.getURL("/auth/facebook"), "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
  },

  casLogin: function() {
    var left, top;
    this.set('authenticate', 'cas');
    left = this.get('lastX') - 400;
    top = this.get('lastY') - 200;
    return window.open("/auth/cas", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
   },

  openidLogin: function(provider) {
    var left = this.get('lastX') - 400;
    var top = this.get('lastY') - 200;
    if (provider === "yahoo") {
      this.set("authenticate", 'yahoo');
      return window.open(Discourse.getURL("/auth/yahoo"), "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
    } else {
      window.open(Discourse.getURL("/auth/google"), "_blank", "menubar=no,status=no,height=500,width=850,left=" + left + ",top=" + top);
      return this.set("authenticate", 'google');
    }
  },

  githubLogin: function() {
    this.set('authenticate', 'github');
    var left = this.get('lastX') - 400;
    var top = this.get('lastY') - 200;
    return window.open(Discourse.getURL("/auth/github"), "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
  },

  personaLogin: function() {
    navigator.id.request();
  },

  authenticationComplete: function(options) {
    if (options.awaiting_approval) {
      this.flash(Em.String.i18n('login.awaiting_approval'), 'success');
      this.set('authenticate', null);
      return;
    }
    if (options.awaiting_activation) {
      this.flash(Em.String.i18n('login.awaiting_confirmation'), 'success');
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
    })
    this.send('showCreateAccount');
  }

});