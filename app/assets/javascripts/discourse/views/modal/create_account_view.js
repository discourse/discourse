/**
  This view handles the create account modal

  @class CreateAccountView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.CreateAccountView = Discourse.ModalBodyView.extend({
  templateName: 'modal/create_account',
  title: I18n.t('create_account.title'),

  didInsertElement: function(e) {

    this._super();

    // allows the submission the form when pressing 'ENTER' on *any* text input field
    // but only when the submit button is enabled
    var createAccountController = this.get('controller');
    Em.run.schedule('afterRender', function() {
      $("input[type='text'], input[type='password']").keydown(function(e) {
        if (createAccountController.get('submitDisabled') === false && e.keyCode === 13) {
          createAccountController.createAccount();
        }
      });
    });
  }

});
