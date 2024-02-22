import { withPluginApi } from "discourse/lib/plugin-api";
import { addSection } from "../lib/styleguide";

/**
 * Add a section to the styleguide
 *
 * @function addStyleguideSection
 * @param {Object} section
 * @param {Component} section.component
 * @param {string} options.id
 * @param {string} options.category
 * @param {number} [options.priority]
 * @example
 *
 * import fidget from "../components/styleguide/molecules/fidget";
 *
 * api.addStyleguideSection({
 *   component: fidget,
 *   id: "fidget",
 *   category: "molecules",
 *   priority: 0,
 * });
 */

export default {
  name: "styleguide-plugin-api",
  before: "inject-discourse-objects",

  initialize() {
    withPluginApi("1.2.0", (api) => {
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
