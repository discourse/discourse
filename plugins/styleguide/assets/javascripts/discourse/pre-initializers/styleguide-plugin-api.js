import { withPluginApi } from "discourse/lib/plugin-api";
import { addSection } from "../lib/styleguide.js";

/**
 * Add a section to the styleguide
 *
 * @function addStyleguideSection
 * @param {Object} section
 * @param {() => Component | Promise<Component>} section.component - Returns the section's
 *   component. It runs when the section is visited, so the component can load on demand.
 * @param {string} options.id
 * @param {string} options.category
 * @param {number} [options.priority]
 * @example
 *
 * api.addStyleguideSection({
 *   component: async () =>
 *     (await import("../components/styleguide/molecules/fidget.gjs")).default,
 *   id: "fidget",
 *   category: "molecules",
 *   priority: 0,
 * });
 */

export default {
  name: "styleguide-plugin-api",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      const apiPrototype = Object.getPrototypeOf(api);

      if (!apiPrototype.hasOwnProperty("addStyleguideSection")) {
        Object.defineProperty(apiPrototype, "addStyleguideSection", {
          value(section) {
            addSection(section);
          },
        });
      }
    });
  },
};
