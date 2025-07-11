import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "discourse-topic-voting-transformers",
  before: "freeze-valid-transformers",

  initialize() {
    withPluginApi("1.35.0", (api) => {
      api.addBehaviorTransformerName("topic-vote-button-click");
    });
  },
};
