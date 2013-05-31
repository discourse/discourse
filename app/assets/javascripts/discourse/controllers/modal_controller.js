/**
  This controller supports actions related to showing modals

  @class ModalController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.ModalController = Discourse.Controller.extend({

  /**
    Close the modal.

    @method closeModal
  **/
  closeModal: function() {
    // Currently uses jQuery to hide it.
    $('#discourse-modal').modal('hide');
  }

});


