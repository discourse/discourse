import { withPluginApi } from "discourse/lib/plugin-api";
import { addSection } from "../lib/styleguide";

/**
 * Callback when the sate of the chat drawer changes
 *
 * @function addStyleguideSection
 * @param {string} componentName
 * @example
 *
 * api.addStyleguideSection("");
 */

export default {
  name: "styleguide-plugin-api",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi("1.2.0", (api) => {
      const apiPrototype = Object.getPrototypeOf(api);

      if (!apiPrototype.hasOwnProperty("addStyleguideSection")) {
        Object.defineProperty(apiPrototype, "addStyleguideSection", {
          value(componentName) {
            addSection(componentName);
          },
        });
      }
    });
  },
};
