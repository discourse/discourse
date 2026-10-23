import { apiInitializer } from "discourse/lib/api";
import AdminAssistantWorkflowPreview from "../components/admin-assistant/workflow-preview.gjs";
import { extractWorkflowPreview } from "../lib/admin-assistant/workflow-preview.js";

export function decorateWorkflowPreview(element, helper, message) {
  if (
    !helper.renderGlimmer ||
    !message?.blocks?.some((block) => block.type === "confirmation") ||
    !extractWorkflowPreview(element.innerHTML)
  ) {
    return;
  }

  const code = element.querySelector("pre code.lang-admin-assistant-workflow");
  const source = new DOMParser()
    .parseFromString(message.cooked ?? "", "text/html")
    .querySelector("pre code.lang-admin-assistant-workflow");
  if (!code || !source || code.textContent !== source.textContent) {
    return;
  }

  const target = element.ownerDocument.createElement("div");
  code.closest("pre").replaceWith(target);
  helper.renderGlimmer(
    target,
    <template><AdminAssistantWorkflowPreview @message={{message}} /></template>
  );
}

export default apiInitializer((api) => {
  api.decorateChatMessage?.(decorateWorkflowPreview);
});
