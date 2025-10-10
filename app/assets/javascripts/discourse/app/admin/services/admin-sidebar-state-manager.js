import Service, { service } from "@ember/service";
import scrollLock from "discourse/lib/scroll-lock";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import AdminSearchModal from "admin/components/modal/admin-search";

export default class AdminSidebarStateManager extends Service {
  @service sidebarState;
  @service header;

  keywords = {};

  setLinkKeywords(link_name, keywords) {
    if (!this.keywords[link_name]) {
      this.keywords[link_name] = {
        navigation: keywords.map((keyword) => keyword.toLowerCase()),
      };
      return;
    }

    this.keywords[link_name].navigation = [
      ...new Set(
        this.keywords[link_name].navigation.concat(
          keywords.map((keyword) => keyword.toLowerCase())
        )
      ),
    ];
  }

  maybeForceAdminSidebar(opts = {}) {
    opts.onlyIfAlreadyActive ??= true;

    const isAdminSidebarActive =
      this.sidebarState.currentPanel?.key === ADMIN_PANEL;

    if (!opts.onlyIfAlreadyActive) {
      return this.#forceAdminSidebar();
    }

    if (isAdminSidebarActive) {
      return this.#forceAdminSidebar();
    } else {
      this.sidebarState.isForcingSidebar = false;
      return false;
    }
  }

  stopForcingAdminSidebar() {
    this.sidebarState.setPanel(MAIN_PANEL);
    this.sidebarState.isForcingSidebar = false;
  }

  get modals() {
    return { adminSearch: AdminSearchModal };
  }

  #forceAdminSidebar() {
    this.sidebarState.setPanel(ADMIN_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.sidebarState.isForcingSidebar = true;

    // we may navigate to admin from the header dropdown
    // and when we do, we have to close it
    if (this.sidebarState.sidebarHidden) {
      this.header.hamburgerVisible = false;
      scrollLock(false);
    }

    return true;
  }
}
