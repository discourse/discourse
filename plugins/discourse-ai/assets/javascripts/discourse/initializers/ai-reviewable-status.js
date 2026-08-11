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

      api.registerReviewableComponent(
        "ReviewableAiChatMessage",
        async () =>
          (await import("../components/reviewable/ai-chat-message")).default
      );
      api.registerReviewableComponent(
        "ReviewableAiPost",
        async () => (await import("../components/reviewable/ai-post")).default
      );
      api.registerReviewableComponent(
        "ReviewableAiToolAction",
        async () =>
          (await import("../components/reviewable/ai-tool-action")).default
      );
    });
  },
};
