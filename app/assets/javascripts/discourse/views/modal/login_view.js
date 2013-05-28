/**
  A modal view for handling user logins

  @class LoginView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.LoginView = Discourse.ModalBodyView.extend({
  templateName: 'modal/login',
  title: Em.String.i18n('login.title'),
  authenticate: null,
  loggingIn: false,


  site: function() {
    return Discourse.Site.instance();
  }.property(),

  showView: function(view) {
    return this.get('controller').show(view);
  },

  newAccount: function() {
    return this.showView(Discourse.CreateAccountView.create());
  },

  forgotPassword: function() {
    return this.showView(Discourse.ForgotPasswordView.create());
  },

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

    var loginView = this;
    Discourse.ajax("/session", {
      data: { login: this.get('loginName'), password: this.get('loginPassword') },
      type: 'POST'
    }).then(function (result) {
      // Successful login
      if (result.error) {
        loginView.set('loggingIn', false);
        if( result.reason === 'not_activated' ) {
          return loginView.showView(Discourse.NotActivatedView.create({
            username: loginView.get('loginName'),
            sentTo: result.sent_to_email,
            currentEmail: result.current_email
          }));
        }
        loginView.flash(result.error, 'error');
      } else {
        // Trigger the browser's password manager using the hidden static login form:
        var $hidden_login_form = $('#hidden-login-form');
        $hidden_login_form.find('input[name=username]').val(loginView.get('loginName'));
        $hidden_login_form.find('input[name=password]').val(loginView.get('loginPassword'));
        $hidden_login_form.find('input[name=redirect]').val(window.location.href);
        $hidden_login_form.find('input[name=authenticity_token]').val($('meta[name=csrf-token]').attr('content'));
        $hidden_login_form.submit();
      }

    }, function(result) {
      // Failed to login
      loginView.flash(Em.String.i18n('login.error'), 'error');
      loginView.set('loggingIn', false);
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
    // Get username and password from the browser's password manager,
    // if it filled the hidden static login form:
    this.set('loginName', $('#hidden-login-form input[name=username]').val());
    this.set('loginPassword', $('#hidden-login-form input[name=password]').val());

    var loginView = this;
    Em.run.schedule('afterRender', function() {
      $('#login-account-password').keydown(function(e) {
        if (e.keyCode === 13) {
          loginView.login();
        }
      });
    });
  }

});


