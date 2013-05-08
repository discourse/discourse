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
    var modalBodyView = this;
    Em.run.next(function() { modalBodyView.$('form input:first').focus(); });
  },

  // Pass the errors to our errors view
  displayErrors: function(errors, callback) {
    this.set('parentView.parentView.modalErrorsView.errors', errors);
    if (typeof callback === "function") callback();
  },

  // Just use jQuery to show an alert. We don't need anythign fancier for now
  // like an actual ember view
  flash: function(msg, flashClass) {
    if (!flashClass) flashClass = "success";
    var $alert = $('#modal-alert').hide().removeClass('alert-error', 'alert-success');
    $alert.addClass("alert alert-" + flashClass).html(msg);
    $alert.fadeIn();
  }
});


