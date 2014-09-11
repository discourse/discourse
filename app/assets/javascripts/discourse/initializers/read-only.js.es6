/**
  Subscribe to "read-only" status change events via the Message Bus
**/
export default {
  name: "read-only",
  after: "message-bus",

  initialize: function () {
    if (!Discourse.MessageBus) { return; }

    Discourse.MessageBus.subscribe("/site/read-only", function (enabled) {
      Discourse.Site.currentProp('isReadOnly', enabled);
    });
  }
};
