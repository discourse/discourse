import { apiInitializer } from "discourse/lib/api";
import AiToolApproval from "../components/ai-tool-approval";

function initializeAiToolApproval(api) {
  api.decorateCookedElement(
    (element, helper) => {
      if (!helper.renderGlimmer) {
        return;
      }

      // The card markup is globally allow-listed, so a regular user could
      // embed it in their own post. Only mount the actionable card inside
      // bot-authored posts (bot/system users have a non-positive id); anyone
      // else's `div.ai-tool-approval` stays inert. Server-side authz on the
      // /review load and perform endpoints remains the real gate.
      const post = helper.getModel?.();
      if (!post?.id || post.user_id > 0) {
        return;
      }

      [
        ...element.querySelectorAll("div[data-ai-tool-approval-reviewable-id]"),
      ].forEach((cardElement) => {
        const reviewableId = cardElement.getAttribute(
          "data-ai-tool-approval-reviewable-id"
        );

        helper.renderGlimmer(
          cardElement,
          <template><AiToolApproval @reviewableId={{reviewableId}} /></template>
        );
      });
    },
    {
      id: "ai-tool-approval",
      onlyStream: true,
    }
  );
}

export default apiInitializer(initializeAiToolApproval);
