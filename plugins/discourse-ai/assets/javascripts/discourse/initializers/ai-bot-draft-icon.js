import { apiInitializer } from "discourse/lib/api";
import { isAiBotRecipient } from "../lib/ai-bot-helper";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();

  if (!currentUser?.ai_enabled_chat_bots?.length) {
    return;
  }

  api.registerValueTransformer("draft-icon", ({ value, context }) => {
    return isAiBotRecipient(context.draft?.data?.recipients, currentUser)
      ? "robot"
      : value;
  });
});
