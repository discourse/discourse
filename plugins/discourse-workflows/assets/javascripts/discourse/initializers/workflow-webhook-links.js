import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize() {
    withPluginApi((api) => {
      api.registerValueTransformer("route-to-url", ({ value }) => {
        if (value?.includes("/workflows/webhooks/")) {
          window.location.href = value;
          return "";
        }
        return value;
      });
    });
  },
};
