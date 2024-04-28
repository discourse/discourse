import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";

export const CHAT_PANEL = "chat";

export function initSidebarState(api, user) {
  const chatSeparateSidebarMode = getUserChatSeparateSidebarMode(user);
  if (chatSeparateSidebarMode.fullscreen) {
    api.setCombinedSidebarMode();
    api.showSidebarSwitchPanelButtons();
  } else if (chatSeparateSidebarMode.always) {
    api.setSeparatedSidebarMode();
  } else {
    api.setCombinedSidebarMode();
    api.hideSidebarSwitchPanelButtons();
  }

  if (api.getSidebarPanel()?.key === ADMIN_PANEL) {
    return;
  }

  api.setSidebarPanel(MAIN_PANEL);
}
