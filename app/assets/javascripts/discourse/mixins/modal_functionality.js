/**
  This mixin provides functionality to modal controllers

  @class Discourse.ModalFunctionality
  @extends Ember.Mixin
  @namespace Discourse
  @module Discourse
**/
Discourse.ModalFunctionality = Em.Mixin.create({
  needs: ['modal'],

  /**
    Flash a message at the top of the modal

    @method blank
    @param {String} message I18n name of the message
    @param {String} messageClass CSS class to apply
    @return {Boolean}
  **/
  flash: function(message, messageClass) {
    this.set('flashMessage', Em.Object.create({
      message: message,
      messageClass: messageClass
    }));
  }

});


