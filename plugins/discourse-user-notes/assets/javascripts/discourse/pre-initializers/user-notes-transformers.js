import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "freeze-valid-transformers",

  initialize() {
    withPluginApi((api) => {
      api.addValueTransformerName("user-notes-icon-placement");
    });
  },
};
