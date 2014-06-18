/**
  Subscribe to "read-only" status change events via the Message Bus
**/
export default {
  name: "read-only",
  after: "message-bus",

  initialize: function () {
    // initialize read-only mode and subscribe to updates via the message bus
    Discourse.set("isReadOnly", Discourse.Site.currentProp("is_readonly"));

    if (!Discourse.MessageBus) { return; }

    Discourse.MessageBus.subscribe("/site/read-only", function (enabled) {
      Discourse.set("isReadOnly", enabled);
    });
  }
};
