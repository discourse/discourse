/**
  Initialize the message bus to receive messages.
**/
export default {
  name: "message-bus",
  after: 'inject-objects',

  initialize: function() {

    // We don't use the message bus in testing
    if (Discourse.testing) { return; }

    Discourse.MessageBus.alwaysLongPoll = Discourse.Environment === "development";
    Discourse.MessageBus.start();
    Discourse.KeyValueStore.init("discourse_", Discourse.MessageBus);
  }
};
