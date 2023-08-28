import { getUserChatSeparateSidebarMode } from "discourse/plugins/chat/discourse/lib/get-user-chat-separate-sidebar-mode";

export function initSidebarState(api, user) {
  api.setSidebarPanel("main");

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
}
