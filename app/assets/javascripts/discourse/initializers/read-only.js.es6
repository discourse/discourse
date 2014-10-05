/**
  Subscribe to "read-only" status change events via the Message Bus
**/
export default {
  name: "read-only",
  after: "message-bus",

  initialize: function (container) {
    if (!Discourse.MessageBus) { return; }

    var site = container.lookup('site:main');
    Discourse.MessageBus.subscribe("/site/read-only", function (enabled) {
      site.currentProp('isReadOnly', enabled);
    });
  }
};
