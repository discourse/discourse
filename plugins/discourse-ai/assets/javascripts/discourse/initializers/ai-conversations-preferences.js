import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const settings = api.container.lookup("service:site-settings");

  if (!settings.ai_bot_enable_docked_composer) {
    return;
  }

  api.addSaveableUserOption("ai_conversations_send_on_enter", {
    page: "interface",
  });
});
