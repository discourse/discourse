import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "freeze-valid-transformers",

  initialize() {
    withPluginApi((api) => {
      api.addBehaviorTransformerName("chat-message-decorate");
      api.addValueTransformerName("chat-message-secondary-actions");
      api.addValueTransformerName("chat-presence-active");
    });
  },
};
