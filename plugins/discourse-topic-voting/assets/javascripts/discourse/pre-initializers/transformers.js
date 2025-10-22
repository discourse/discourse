import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-topic-voting-transformers",
  before: "freeze-valid-transformers",

  initialize() {
    withPluginApi((api) => {
      api.addBehaviorTransformerName("topic-vote-button-click");
    });
  },
};
