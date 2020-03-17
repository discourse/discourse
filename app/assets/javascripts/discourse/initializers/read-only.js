// Subscribe to "read-only" status change events via the Message Bus
export default {
  name: "read-only",
  after: "message-bus",

  initialize(container) {
    const messageBus = container.lookup("message-bus:main");
    if (!messageBus) {
      return;
    }

    const site = container.lookup("site:main");
    messageBus.subscribe("/site/read-only", function(enabled) {
      site.set("isReadOnly", enabled);
    });
  }
};
