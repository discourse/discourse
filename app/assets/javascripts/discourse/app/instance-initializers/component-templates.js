import ClassicComponent from "@ember/component";
import DiscourseTemplateMap from "discourse/lib/discourse-template-map";

// Looks for `**/templates/components/**` in themes and plugins, and registers
// a classic component backing class for it, for backwards compatibility.
// These templates will all be raising the `component-template-resolving` deprecation,
// so there's no need to emit our own deprecation here.
export default {
  after: ["populate-template-map"],

  initialize(owner) {
    for (const templatePath of DiscourseTemplateMap.templates.keys()) {
      if (!templatePath.startsWith("components/")) {
        continue;
      }

      const componentName = templatePath.slice("components/".length);
      const component = owner.resolveRegistration(`component:${componentName}`);

      if (!component) {
        owner.register(`component:${componentName}`, ClassicComponent);
      }
    }
  },
};
