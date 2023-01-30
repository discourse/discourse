import DiscourseTemplateMap from "discourse-common/lib/discourse-template-map";
import * as GlimmerManager from "@glimmer/manager";

const COLOCATED_TEMPLATE_OVERRIDES = new Map();

// This patch is not ideal, but Ember does not allow us to change a component template after initial association
// https://github.com/glimmerjs/glimmer-vm/blob/03a4b55c03/packages/%40glimmer/manager/lib/public/template.ts#L14-L20
const originalGetTemplate = GlimmerManager.getComponentTemplate;
GlimmerManager.getComponentTemplate = (component) => {
  return (
    COLOCATED_TEMPLATE_OVERRIDES.get(component) ??
    originalGetTemplate(component)
  );
};

export default {
  name: "colocated-template-overrides",
  after: "populate-template-map",

  initialize(container) {
    this.eachThemePluginTemplate((templateKey, moduleNames) => {
      if (!templateKey.startsWith("components/")) {
        return;
      }

      if (DiscourseTemplateMap.coreTemplates.has(templateKey)) {
        // It's a non-colocated core component. Template will be overridden at runtime.
        return;
      }

      const componentName = templateKey.slice("components/".length);
      const component = container.owner.resolveRegistration(
        `component:${componentName}`
      );

      if (component && originalGetTemplate(component)) {
        const finalOverrideModuleName = moduleNames[moduleNames.length - 1];
        const overrideTemplate = require(finalOverrideModuleName).default;

        COLOCATED_TEMPLATE_OVERRIDES.set(component, overrideTemplate);
      }
    });
  },

  eachThemePluginTemplate(cb) {
    for (const [key, value] of DiscourseTemplateMap.pluginTemplates) {
      cb(key, value);
    }

    for (const [key, value] of DiscourseTemplateMap.themeTemplates) {
      cb(key, value);
    }
  },

  teardown() {
    COLOCATED_TEMPLATE_OVERRIDES.clear();
  },
};
