// Initialize the message bus to receive messages.
export default {
  name: "message-bus",
  after: 'inject-objects',

  initialize(container) {
    // We don't use the message bus in testing
    if (Discourse.testing) { return; }

    const messageBus = container.lookup('message-bus:main');

    const deprecatedBus = {};
    deprecatedBus.prototype = messageBus;
    deprecatedBus.subscribe = function() {
      Ember.warn("Discourse.MessageBus is deprecated. Use `this.messageBus` instead");
      messageBus.subscribe.apply(messageBus, Array.prototype.slice(arguments));
    };
    Discourse.MessageBus = deprecatedBus;

    messageBus.alwaysLongPoll = Discourse.Environment === "development";
    messageBus.start();
    Discourse.KeyValueStore.init("discourse_", messageBus);
  }
};
