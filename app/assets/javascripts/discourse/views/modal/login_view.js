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


  mouseMove: function(e) {
    this.set('controller.lastX', e.screenX);
    this.set('controller.lastY', e.screenY);
  },

  didInsertElement: function(e) {

    this._super();

    var loginController = this.get('controller');

    // Get username and password from the browser's password manager,
    // if it filled the hidden static login form:
    loginController.set('loginName', $('#hidden-login-form input[name=username]').val());
    loginController.set('loginPassword', $('#hidden-login-form input[name=password]').val());


    Em.run.schedule('afterRender', function() {
      $('#login-account-password').keydown(function(e) {
        if (e.keyCode === 13) {
          loginController.login();
        }
      });
    });
  }

});


