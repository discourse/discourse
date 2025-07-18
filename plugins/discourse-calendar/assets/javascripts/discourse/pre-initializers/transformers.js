import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "freeze-valid-transformers",
  initialize() {
    withPluginApi("1.33.0", (api) => {
      api.addValueTransformerName(
        "discourse-calendar-event-more-menu-should-show-participants"
      );
    });
  },
};
