import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const settings = api.container.lookup("service:site-settings");

  if (
    !settings.ai_bot_enabled ||
    !currentUser?.can_use_ai_bot_discover_persona
  ) {
    return;
  }

  api.addSaveableUserOptionField("ai_search_discoveries");
});
