import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/two_factor_authentication_code_verifier',
  title: I18n.t('login.verify_code_title'),
  classNames: ['two-factor-authentication-modal'],

  mouseMove(e) {
    this.set('controller.lastX', e.screenX);
    this.set('controller.lastY', e.screenY);
  },

  _setup: function() {
    const verifyController = this.get('controller');

    Em.run.schedule('afterRender', function() {
      $('#two-factor-authentication-code').keydown(function(e) {
        if (e.keyCode === 13) {
          e.preventDefault();
          verifyController.send('verify');
        }
      });
    });
  }.on('didInsertElement')

});
