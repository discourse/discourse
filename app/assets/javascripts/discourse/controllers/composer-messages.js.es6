// A controller for displaying messages as the user composes a message.
export default Ember.ArrayController.extend({
  needs: ['composer'],

  // Whether we've checked our messages
  checkedMessages: false,

  _init: function() {
    this.reset();
  }.on("init"),

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
    }
  },

  // Resets all active messages.
  // For example if composing a new post.
  reset() {
    this.clear();
    this.setProperties({
      messagesByTemplate: {},
      queuedForTyping: [],
      checkedMessages: false
    });
  },

  // Called after the user has typed a reply.
  // Some messages only get shown after being typed.
  typedReply() {
    this.get('queuedForTyping').forEach(msg => this.send("popup", msg));
  },

  groupsMentioned(groups) {
    // reset existing messages, this should always win it is critical
    this.reset();
    groups.forEach(group => {
      const msg = I18n.t('composer.group_mentioned', {
        group: "@" + group.name,
        count: group.user_count,
        group_link: Discourse.getURL(`/group/${group.name}/members`)
      });
      this.send("popup",
        Em.Object.create({
          templateName: 'composer/group-mentioned',
          body: msg})
        );
    });
  },

  // Figure out if there are any messages that should be displayed above the composer.
  queryFor(composer) {
    if (this.get('checkedMessages')) { return; }

    const self = this;
    var queuedForTyping = self.get('queuedForTyping');

    Discourse.ComposerMessage.find(composer).then(messages => {
      self.set('checkedMessages', true);
      messages.forEach(msg => msg.wait_for_typing ? queuedForTyping.addObject(msg) : self.send("popup", msg));
    });
  }

});
