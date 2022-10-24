export default {
  name: "welcome-topic-banner",
  after: "message-bus",

  initialize(container) {
    const site = container.lookup("service:site");

    if (site.show_welcome_topic_banner) {
      const messageBus = container.lookup("service:message-bus");
      messageBus.subscribe("/site/welcome-topic-banner", (disabled) => {
        site.set("show_welcome_topic_banner", disabled);
      });
    }
  },
};
