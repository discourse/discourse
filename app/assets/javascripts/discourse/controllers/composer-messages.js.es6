// A controller for displaying messages as the user composes a message.
export default Ember.ArrayController.extend({
  needs: ['composer'],

  // Whether we've checked our messages
  checkedMessages: false,

  /**
    Initialize the controller
  **/
  init: function() {
    this._super();
    this.reset();
  },

  actions: {
    /**
      Closes and hides a message.

      @method closeMessage
      @params {Object} message The message to dismiss
    **/
    closeMessage: function(message) {
      this.removeObject(message);
    },

    hideMessage: function(message) {
      var messagesByTemplate = this.get('messagesByTemplate'),
        templateName = message.get('templateName');

      // kind of hacky but the visibility depends on this
      messagesByTemplate[templateName] = undefined;
      this.removeObject(message);
    }
  },

  /**
    Displays a new message

    @method popup
    @params {Object} msg The message to display
  **/
  popup: function(msg) {
    var messagesByTemplate = this.get('messagesByTemplate'),
        templateName = msg.get('templateName'),
        existing = messagesByTemplate[templateName];

    if (!existing) {
      this.pushObject(msg);
      messagesByTemplate[templateName] = msg;
    }
  },

  /**
    Resets all active messages. For example if composing a new post.

    @method reset
  **/
  reset: function() {
    this.clear();
    this.set('messagesByTemplate', {});
    this.set('queuedForTyping', []);
    this.set('checkedMessages', false);
  },

  /**
    Called after the user has typed a reply. Some messages only get shown after being
    typed.

    @method typedReply
  **/
  typedReply: function() {
    var self = this;
    this.get('queuedForTyping').forEach(function (msg) {
      self.popup(msg);
    });
  },

  /**
    Figure out if there are any messages that should be displayed above the composer.

    @method queryFor
    @params {Discourse.Composer} composer The composer model
  **/
  queryFor: function(composer) {
    if (this.get('checkedMessages')) { return; }

    var self = this,
        queuedForTyping = self.get('queuedForTyping');

    Discourse.ComposerMessage.find(composer).then(function (messages) {
      self.set('checkedMessages', true);
      messages.forEach(function (msg) {
        if (msg.wait_for_typing) {
          queuedForTyping.addObject(msg);
        } else {
          self.popup(msg);
        }
      });
    });
  }

});
