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
    var _this = this;
    Em.run.next(function() {
      _this.$('form input:first').focus();
    });
  },

  // Pass the errors to our errors view
  displayErrors: function(errors, callback) {
    this.set('parentView.parentView.modalErrorsView.errors', errors);
    typeof callback === "function" ? callback() : void 0;
  },

  // Just use jQuery to show an alert. We don't need anythign fancier for now
  // like an actual ember view
  flash: function(msg, flashClass) {
    var $alert;
    if (!flashClass) flashClass = "success";
    $alert = $('#modal-alert').hide().removeClass('alert-error', 'alert-success');
    $alert.addClass("alert alert-" + flashClass).html(msg);
    $alert.fadeIn();
  }
});


