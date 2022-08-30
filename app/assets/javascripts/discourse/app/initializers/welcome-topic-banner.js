export default {
  name: "welcome-topic-banner",
  after: "message-bus",

  initialize(container) {
    const messageBus = container.lookup("service:message-bus");
    if (!messageBus) {
      return;
    }

    const site = container.lookup("service:site");
    if (site.get("show_welcome_topic_banner")) {
      messageBus.subscribe("/site/welcome-topic-banner", function (disabled) {
        site.set("show_welcome_topic_banner", disabled);
      });
    }
  },
};
