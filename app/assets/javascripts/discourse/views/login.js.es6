import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/login',
  title: I18n.t('login.title'),
  classNames: ['login-modal'],

  mouseMove: function(e) {
    this.set('controller.lastX', e.screenX);
    this.set('controller.lastY', e.screenY);
  },

  _setup: function() {
    const loginController = this.get('controller');

    // Get username and password from the browser's password manager,
    // if it filled the hidden static login form:
    var prefillUsername = $('#hidden-login-form input[name=username]').val();
    if (prefillUsername) {
      loginController.set('loginName', prefillUsername);
      loginController.set('loginPassword', $('#hidden-login-form input[name=password]').val());
    } else if ($.cookie('email')) {
      loginController.set('loginName', $.cookie('email'));
    }

    Em.run.schedule('afterRender', function() {
      $('#login-account-password, #login-account-name').keydown(function(e) {
        if (e.keyCode === 13 && !loginController.get('loginDisabled')) {
          loginController.send('login');
        }
      });
    });
  }.on('didInsertElement')
});
