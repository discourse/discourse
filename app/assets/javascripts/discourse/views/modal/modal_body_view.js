/**
  A base class for helping us display modal content

  @class ModalBodyView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ModalBodyView = Discourse.View.extend({

  // Focus on first element
  didInsertElement: function() {
    $('#discourse-modal').modal('show');

    $('#modal-alert').hide();

    if (!Discourse.Mobile.mobileView) {
      var modalBodyView = this;
      Em.run.schedule('afterRender', function() {
        modalBodyView.$('input:first').focus();
      });
    }

    var title = this.get('title');
    if (title) {
      this.set('controller.controllers.modal.title', title);
    }
  },

  flashMessageChanged: function() {
    var flashMessage = this.get('controller.flashMessage');
    if (flashMessage) {
      var messageClass = flashMessage.get('messageClass') || 'success';
      var $alert = $('#modal-alert').hide().removeClass('alert-error', 'alert-success');
      $alert.addClass("alert alert-" + messageClass).html(flashMessage.get('message'));
      $alert.fadeIn();
    }
  }.observes('controller.flashMessage')

});


