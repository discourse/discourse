import { withPluginApi } from "discourse/lib/plugin-api";
import Plugins from "discourse-plugins-v2/events/decorate-non-stream-cooked-element";

// TODO: find a better spot for this than in an initializer

export default {
  initialize() {
    withPluginApi("1.15.0", (api) => {
      for (const Plugin of Plugins) {
        const { handler } = Plugin.module.default;
        api.onAppEvent("decorate-non-stream-cooked-element", handler);
      }
    });
  },
};
