import { apiInitializer } from "discourse/lib/api";
import AiBotChatsTab from "../components/ai-bot-chats-tab";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.ai_bot_enabled) {
    return;
  }

  api.renderInOutlet("user-messages-nav-bottom", AiBotChatsTab);
});
