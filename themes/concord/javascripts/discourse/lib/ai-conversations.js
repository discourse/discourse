import { AI_PANEL } from "./constants.js";

/**
 * Discourse AI's conversations, shown in the sidebar in place of the channels
 * without leaving the page, as the DMs are. Its own pages still bring the
 * list up, and leaving them puts the channels back, as Discourse AI does.
 */
export default class AiConversations {
  constructor(owner, directMessages) {
    this.manager = owner.lookup("service:ai-conversations-sidebar-manager");
    this.sidebarState = owner.lookup("service:sidebar-state");
    this.directMessages = directMessages;
  }

  get active() {
    return this.sidebarState.currentPanelKey === AI_PANEL;
  }

  toggle() {
    this.show(!this.active);
  }

  show(active) {
    if (active) {
      this.manager?.forceCustomSidebar();
    } else {
      this.release();
      this.directMessages.show(false);
    }
  }

  // Lets go of the list, leaving the panel to whoever shows one next.
  release() {
    if (this.sidebarState.forcingSidebarPanel === AI_PANEL) {
      this.manager?.stopForcingCustomSidebar();
    }
  }
}
