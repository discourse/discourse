import { withPluginApi } from "discourse/lib/plugin-api";
import DataExplorerWorkflowAiQuery from "discourse/plugins/discourse-data-explorer/discourse/components/data-explorer-workflow-ai-query";

export default {
  name: "data-explorer-register-workflow-ai-query",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.enable_discourse_workflows) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "workflow-field-control",
        ({ value, context }) => {
          if (
            context.node?.type !== "action:sql" ||
            context.fieldName !== "query" ||
            context.nodeParameters?.operation !== "raw"
          ) {
            return value;
          }

          return {
            ...value,
            addons: [...(value.addons || []), DataExplorerWorkflowAiQuery],
          };
        }
      );
    });
  },
};
