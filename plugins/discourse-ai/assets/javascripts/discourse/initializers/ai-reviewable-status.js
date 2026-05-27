import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "ai-reviewable-status",

  initialize() {
    withPluginApi((api) => {
      api.registerReviewableStatusName(
        "ReviewableAiToolAction",
        "approved_tool_action",
        "rejected_tool_action"
      );
    });
  },
};
