/**
  This view handles the modal for when a user forgets their password

  @class ForgotPasswordView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.ForgotPasswordView = Discourse.ModalBodyView.extend({
  templateName: 'modal/forgot_password',
  title: Em.String.i18n('forgot_password.title')
});


