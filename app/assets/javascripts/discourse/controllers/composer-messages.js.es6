// A controller for displaying messages as the user composes a message.
export default Ember.ArrayController.extend({
  needs: ['composer'],

  // Whether we've checked our messages
  checkedMessages: false,

  init() {
    this._super();
    this.reset();
  },

  actions: {
    closeMessage(message) {
      this.removeObject(message);
    },

    hideMessage(message) {
      this.removeObject(message);
      // kind of hacky but the visibility depends on this
      this.get('messagesByTemplate')[message.get('templateName')] = undefined;
    },

    popup(message) {
      let messagesByTemplate = this.get('messagesByTemplate');
      const templateName = message.get('templateName');

      if (!messagesByTemplate[templateName]) {
        this.pushObject(message);
        messagesByTemplate[templateName] = message;
      }
    },
  },

  /**
    Resets all active messages. For example if composing a new post.

    @method reset
  **/
  reset() {
    this.clear();
    this.setProperties({
      messagesByTemplate: {},
      queuedForTyping: [],
      checkedMessages: false
    });
  },

  /**
    Called after the user has typed a reply. Some messages only get shown after being
    typed.

    @method typedReply
  **/
  typedReply() {
    this.get('queuedForTyping').forEach(msg => this.popup(msg));
  },

  /**
    Figure out if there are any messages that should be displayed above the composer.

    @method queryFor
    @params {Discourse.Composer} composer The composer model
  **/
  queryFor(composer) {
    if (this.get('checkedMessages')) { return; }

    const self = this;
    let queuedForTyping = self.get('queuedForTyping');

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
