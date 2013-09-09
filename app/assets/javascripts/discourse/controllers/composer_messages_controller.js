/**
  A controller for displaying messages as the user composes a message.

  @class ComposerMessagesController
  @extends Ember.ArrayController
  @namespace Discourse
  @module Discourse
**/
Discourse.ComposerMessagesController = Ember.ArrayController.extend({
  needs: ['composer'],

  init: function() {
    this._super();
    this.set('messagesByTemplate', {});
  },

  popup: function(msg) {
    var messagesByTemplate = this.get('messagesByTemplate'),
        existing = messagesByTemplate[msg.templateName];

    if (!existing) {
      this.pushObject(msg);
      messagesByTemplate[msg.templateName] = msg;
    }
  },

  closeMessage: function(message) {
    this.removeObject(message);
  }

});