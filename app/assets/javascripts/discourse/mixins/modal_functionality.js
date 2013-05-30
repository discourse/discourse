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
    @param {String} name the name of the property we want to check
    @return {Boolean}
  **/
  flash: function(message, messageClass) {
    this.set('flashMessage', Em.Object.create({
      message: message,
      messageClass: messageClass
    }));
  }

});


