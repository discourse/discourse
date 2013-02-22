
window.Discourse.NotActivatedView = window.Discourse.ModalBodyView.extend(Discourse.Presence, {
  templateName: 'modal/not_activated',
  title: Em.String.i18n('log_in'),
  emailSent: false,

  sendActivationEmail: function() {
    jQuery.get('/users/' + this.get('username') + '/send_activation_email');
    this.set('emailSent', true);
  }
});
