/**
  A modal view for handling user logins

  @class LoginView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.LoginView = Discourse.ModalBodyView.extend({
  templateName: 'modal/login',
  siteBinding: 'Discourse.site',
  title: Em.String.i18n('login.title'),
  authenticate: null,
  loggingIn: false,

  showView: function(view) {
    return this.get('controller').show(view);
  },

  newAccount: function() {
    return this.showView(Discourse.CreateAccountView.create());
  },

  forgotPassword: function() {
    return this.showView(Discourse.ForgotPasswordView.create());
  },

  loginButtonText: (function() {
    if (this.get('loggingIn')) {
      return Em.String.i18n('login.logging_in');
    }
    return Em.String.i18n('login.title');
  }).property('loggingIn'),

  loginDisabled: (function() {
    if (this.get('loggingIn')) {
      return true;
    }
    if (this.blank('loginName') || this.blank('loginPassword')) {
      return true;
    }
    return false;
  }).property('loginName', 'loginPassword', 'loggingIn'),

  login: function() {
    var _this = this;
    this.set('loggingIn', true);
    $.post("/session", {
      login: this.get('loginName'),
      password: this.get('loginPassword')
    }).success(function(result) {
      if (result.error) {
        _this.set('loggingIn', false);
        if( result.reason === 'not_activated' ) {
          return _this.showView(Discourse.NotActivatedView.create({username: _this.get('loginName'), sentTo: result.sent_to_email, currentEmail: result.current_email}));
        }
        _this.flash(result.error, 'error');
      } else {
        return window.location.reload();
      }
    }).fail(function(result) {
      _this.flash(Em.String.i18n('login.error'), 'error');
      return _this.set('loggingIn', false);
    });
    return false;
  },

  authMessage: (function() {
    if (this.blank('authenticate')) {
      return "";
    }
    return Em.String.i18n("login." + (this.get('authenticate')) + ".message");
  }).property('authenticate'),

  twitterLogin: function() {
    var left, top;
    this.set('authenticate', 'twitter');
    left = this.get('lastX') - 400;
    top = this.get('lastY') - 200;
    return window.open("/auth/twitter", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
  },

  facebookLogin: function() {
    var left, top;
    this.set('authenticate', 'facebook');
    left = this.get('lastX') - 400;
    top = this.get('lastY') - 200;
    return window.open("/auth/facebook", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
  },

  openidLogin: function(provider) {
    var left, top;
    left = this.get('lastX') - 400;
    top = this.get('lastY') - 200;
    if (provider === "yahoo") {
      this.set("authenticate", 'yahoo');
      return window.open("/auth/yahoo", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
    } else {
      window.open("/auth/google", "_blank", "menubar=no,status=no,height=500,width=850,left=" + left + ",top=" + top);
      return this.set("authenticate", 'google');
    }
  },

  githubLogin: function() {
    var left, top;
    this.set('authenticate', 'github');
    left = this.get('lastX') - 400;
    top = this.get('lastY') - 200;
    return window.open("/auth/github", "_blank", "menubar=no,status=no,height=400,width=800,left=" + left + ",top=" + top);
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
      window.location.reload();
      return;
    }
    return this.showView(Discourse.CreateAccountView.create({
      accountEmail: options.email,
      accountUsername: options.username,
      accountName: options.name,
      authOptions: Em.Object.create(options)
    }));
  },

  mouseMove: function(e) {
    this.set('lastX', e.screenX);
    return this.set('lastY', e.screenY);
  },

  didInsertElement: function(e) {
    var _this = this;
    return Em.run.next(function() {
      return $('#login-account-password').keydown(function(e) {
        if (e.keyCode === 13) {
          return _this.login();
        }
      });
    });
  }

});


