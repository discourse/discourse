/**
  A base class for helping us display modal content

  @class ModalBodyView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ModalBodyView = Discourse.View.extend({
  focusInput: true,

  _setupModal: function() {
    var self = this,
        $discourseModal = $('#discourse-modal');

    $discourseModal.modal('show');
    $discourseModal.one("hide", function () {
      self.get("controller").send("closeModal");
    });

    $('#modal-alert').hide();

    // Focus on first element
    if (!Discourse.Mobile.mobileView && self.get('focusInput')) {
      Em.run.schedule('afterRender', function() {
        self.$('input:first').focus();
      });
    }

    var title = this.get('title');
    if (title) {
      this.set('controller.controllers.modal.title', title);
    }
  }.on('didInsertElement'),

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


