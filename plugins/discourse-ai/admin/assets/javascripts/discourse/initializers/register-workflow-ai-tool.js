import { withPluginApi } from "discourse/lib/plugin-api";
import AiToolArguments from "discourse/plugins/discourse-ai/admin/components/workflows/ai-tool-arguments";

export default {
  name: "register-workflow-ai-tool",

  initialize(container) {
    if (!container.lookup("service:site-settings").enable_discourse_workflows) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "workflow-field-control",
        ({ value, context }) => {
          if (context.control !== "ai_tool_arguments") {
            return value;
          }

          return { kind: "standalone", renderer: AiToolArguments };
        }
      );
    });
  },
};
