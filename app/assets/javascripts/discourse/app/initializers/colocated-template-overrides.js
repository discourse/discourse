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
  after: ["populate-template-map", "mobile"],

  initialize(container) {
    this.site = container.lookup("service:site");

    this.eachThemePluginTemplate((templateKey, moduleNames, mobile) => {
      if (!mobile && DiscourseTemplateMap.coreTemplates.has(templateKey)) {
        // It's a non-colocated core component. Template will be overridden at runtime.
        return;
      }

      let componentName = templateKey;
      if (mobile) {
        componentName = componentName.slice("mobile/".length);
      }
      componentName = componentName.slice("components/".length);

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
    const { coreTemplates, pluginTemplates, themeTemplates } =
      DiscourseTemplateMap;

    const orderedOverrides = [
      [pluginTemplates, "components/", false],
      [themeTemplates, "components/", false],
    ];

    if (this.site.mobileView) {
      orderedOverrides.push(
        [coreTemplates, "mobile/components/", true],
        [pluginTemplates, "mobile/components/", true],
        [themeTemplates, "mobile/components/", true]
      );
    }

    for (const [map, prefix, mobile] of orderedOverrides) {
      for (const [key, value] of map) {
        if (key.startsWith(prefix)) {
          cb(key, value, mobile);
        }
      }
    }
  },

  teardown() {
    COLOCATED_TEMPLATE_OVERRIDES.clear();
  },
};
