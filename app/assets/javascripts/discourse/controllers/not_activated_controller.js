/**
  Modal displayed to a user when they are not active yet.

  @class NotActivatedController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.NotActivatedController = Discourse.Controller.extend(Discourse.ModalFunctionality, {
  emailSent: false,

  sendActivationEmail: function() {
    Discourse.ajax('/users/' + this.get('username') + '/send_activation_email', {type: 'POST'});
    this.set('emailSent', true);
  }

});