import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  before: "freeze-valid-transformers",
  initialize() {
    withPluginApi((api) => {
      api.addValueTransformerName(
        "discourse-calendar-event-more-menu-should-show-participants"
      );
    });
  },
};
