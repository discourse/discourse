import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "freeze-valid-transformers",

  initialize() {
    withPluginApi((api) => {
      api.addValueTransformerName("workflow-node-defaults");
      api.addValueTransformerName("workflow-node-icons");
      api.addValueTransformerName("workflow-property-engine-controls");
    });
  },
};
