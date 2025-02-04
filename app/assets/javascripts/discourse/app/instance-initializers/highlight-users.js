import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize() {
    withPluginApi("1.36.0", (api) => {
      api.registerValueTransformer("mentions-class", ({ value, context }) => {
        const { user } = context;

        if (user.id < 0) {
          value.push("--bot");
        } else if (user.id === api.getCurrentUser()?.id) {
          value.push("--current");
        } else if (user.username === "here" || user.username === "all") {
          value.push("--wide");
        }

        return value;
      });
    });
  },
};
