/* eslint-disable ember/no-classic-components */
import ClassicComponent, { setComponentTemplate } from "@ember/component";
import deprecated from "discourse/lib/deprecated";
import DiscourseTemplateMap from "discourse/lib/discourse-template-map";

// Looks for `**/templates/components/**` in themes and plugins, and registers
// a classic component backing class for it, for backwards compatibility.
export default {
  after: ["populate-template-map"],

  initialize(owner) {
    for (const [
      templatePath,
      moduleName,
    ] of DiscourseTemplateMap.templates.entries()) {
      if (!templatePath.startsWith("components/")) {
        continue;
      }

      const componentName = templatePath.slice("components/".length);
      let component = owner.resolveRegistration(`component:${componentName}`);

      if (!component) {
        component = class extends ClassicComponent {};
        owner.register(`component:${componentName}`, component);
      }

      deprecated(
        `[${moduleName}] Storing component templates in the 'templates/components/' directory is deprecated. Move them to the 'components/' directory instead.`,
        {
          id: "discourse.component-template-resolving",
          url: "https://meta.discourse.org/t/370019",
        }
      );

      setComponentTemplate(require(moduleName).default, component);
    }
  },
};
