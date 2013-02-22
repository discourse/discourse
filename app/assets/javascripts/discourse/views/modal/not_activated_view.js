/**
  A modal view for telling a user they're not activated

  @class NotActivatedView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.NotActivatedView = Discourse.ModalBodyView.extend({
  templateName: 'modal/not_activated',
  title: Em.String.i18n('log_in'),
  emailSent: false,

  sendActivationEmail: function() {
    jQuery.get('/users/' + this.get('username') + '/send_activation_email');
    this.set('emailSent', true);
  }
});
