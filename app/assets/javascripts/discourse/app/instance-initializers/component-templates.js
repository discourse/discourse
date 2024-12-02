import * as GlimmerManager from "@glimmer/manager";
import ClassicComponent from "@ember/component";
import { isTesting } from "discourse-common/config/environment";
import deprecated from "discourse-common/lib/deprecated";
import DiscourseTemplateMap from "discourse-common/lib/discourse-template-map";

let THROW_GJS_ERROR = isTesting();

/** For use in tests/integration/component-templates-test only */
export function overrideThrowGjsError(value) {
  THROW_GJS_ERROR = value;
}

// We're using a patched version of Ember with a modified GlimmerManager to make the code below work.
// This patch is not ideal, but Ember does not allow us to change a component template after initial association
// https://github.com/glimmerjs/glimmer-vm/blob/03a4b55c03/packages/%40glimmer/manager/lib/public/template.ts#L14-L20

export default {
  after: ["populate-template-map", "mobile"],

  initialize(owner) {
    this.site = owner.lookup("service:site");

    this.eachThemePluginTemplate((templateKey, moduleNames, mobile) => {
      if (!mobile && DiscourseTemplateMap.coreTemplates.has(templateKey)) {
        // It's a non-colocated core component. Template will be overridden at runtime.
        return;
      }

      let componentName = templateKey;
      if (mobile) {
        deprecated(
          `Mobile-specific hbs templates are deprecated. Use responsive CSS or {{#if this.site.mobileView}} instead. [${templateKey}]`,
          {
            id: "discourse.mobile-templates",
          }
        );
        if (this.site.mobileView) {
          componentName = componentName.slice("mobile/".length);
        }
      }

      componentName = componentName.slice("components/".length);

      const component = owner.resolveRegistration(`component:${componentName}`);

      if (!component) {
        // Plugin/theme component template with no backing class.
        // Treat as classic component to emulate pre-template-only-glimmer-component behaviour.
        owner.register(`component:${componentName}`, ClassicComponent);
        return;
      }

      // patched function: doesn't exist on og GlimmerManager. it corresponds to the og GlimmerManager.getComponentTemplate
      const originalTemplate =
        GlimmerManager.getOriginalComponentTemplate(component);
      const isStrictMode = originalTemplate?.()?.parsedLayout?.isStrictMode;
      const finalOverrideModuleName = moduleNames[moduleNames.length - 1];

      if (isStrictMode) {
        const message =
          `[${finalOverrideModuleName}] ${componentName} was authored using gjs and its template cannot be overridden. ` +
          `Ignoring override. For more information on the future of template overrides, see https://meta.discourse.org/t/247487`;
        if (THROW_GJS_ERROR) {
          throw new Error(message);
        } else {
          // eslint-disable-next-line no-console
          console.error(message);
        }
      } else if (originalTemplate) {
        deprecated(
          `[${finalOverrideModuleName}] Overriding component templates is deprecated, and will soon be disabled. Use plugin outlets, CSS, or other customization APIs instead.`,
          {
            id: "discourse.component-template-overrides",
            url: "https://meta.discourse.org/t/247487",
          }
        );

        const overrideTemplate = require(finalOverrideModuleName).default;

        // patched function: doesn't exist on og GlimmerManager
        GlimmerManager.setColocatedTemplateOverride(
          component,
          overrideTemplate
        );
      }
    });
  },

  eachThemePluginTemplate(cb) {
    const { coreTemplates, pluginTemplates, themeTemplates } =
      DiscourseTemplateMap;

    const orderedOverrides = [
      [pluginTemplates, "components/", false],
      [themeTemplates, "components/", false],
      [coreTemplates, "mobile/components/", true],
      [pluginTemplates, "mobile/components/", true],
      [themeTemplates, "mobile/components/", true],
    ];

    for (const [map, prefix, mobile] of orderedOverrides) {
      for (const [key, value] of map) {
        if (key.startsWith(prefix)) {
          cb(key, value, mobile);
        }
      }
    }
  },

  teardown() {
    // patched function: doesn't exist on og GlimmerManager
    GlimmerManager.clearColocatedTemplateOverrides();
  },
};
