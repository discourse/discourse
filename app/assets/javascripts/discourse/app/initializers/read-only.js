// Subscribe to "read-only" status change events via the Message Bus
export default {
  name: "read-only",
  after: "message-bus",

  initialize(container) {
    const messageBus = container.lookup("service:message-bus");
    const site = container.lookup("service:site");
    messageBus.subscribe("/site/read-only", (enabled) => {
      site.set("isReadOnly", enabled);
    });
  },
};
