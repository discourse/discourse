import { bind } from "discourse-common/utils/decorators";

export default {
  name: "welcome-topic-banner",
  after: "message-bus",

  initialize(container) {
    this.site = container.lookup("service:site");
    this.messageBus = container.lookup("service:message-bus");

    if (this.site.show_welcome_topic_banner) {
      this.messageBus.subscribe("/site/welcome-topic-banner", this.onMessage);
    }
  },

  teardown() {
    this.messageBus.unsubscribe("/site/welcome-topic-banner", this.onMessage);
  },

  @bind
  onMessage(disabled) {
    this.site.set("show_welcome_topic_banner", disabled);
  },
};
