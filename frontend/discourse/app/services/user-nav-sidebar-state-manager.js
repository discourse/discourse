import { tracked } from "@glimmer/tracking";
import Service, { service } from "discourse/lib/service";
import scrollLock from "discourse/lib/scroll-lock";
import { MAIN_PANEL, USER_NAV_PANEL } from "discourse/lib/sidebar/panels";
import HeaderService from "discourse/services/header";
import RouteHistoryService from "discourse/services/route-history";
import SidebarStateService from "discourse/services/sidebar-state";
import SiteSettingsService from "discourse/services/site-settings";

/**
 * Hands the sidebar over to the user nav panel while the user routes are
 * active, and gives it back on the way out — the same trade
 * `AdminSidebarStateManager` makes for the admin area.
 */
export default class UserNavSidebarStateManager extends Service {
  @service(() => HeaderService) header;
  @service(() => RouteHistoryService) routeHistory;
  @service(() => SidebarStateService) sidebarState;
  @service(() => SiteSettingsService) siteSettings;

  /**
   * Where the viewer was before they opened a user's admin page. Captured on
   * arrival rather than read from history as they go, so that moving between
   * that page's own tabs doesn't rewrite where they came from.
   */
  @tracked entryURL = null;

  get enteredFromAdmin() {
    return !!this.entryURL?.startsWith("/admin");
  }

  get enabled() {
    return this.siteSettings.sidebar_user_navigation;
  }

  captureEntryPoint() {
    this.entryURL = this.enabled ? (this.routeHistory.lastURL ?? null) : null;
  }

  clearEntryPoint() {
    this.entryURL = null;
  }

  forceUserNavSidebar() {
    if (!this.enabled) {
      return false;
    }

    this.sidebarState.setPanel(USER_NAV_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.sidebarState.isForcingSidebar = true;
    this.sidebarState.forcingSidebarPanel = USER_NAV_PANEL;

    if (this.sidebarState.sidebarHidden) {
      this.header.hamburgerVisible = false;
      scrollLock(false);
    }

    return true;
  }

  stopForcingUserNavSidebar() {
    if (this.sidebarState.forcingSidebarPanel !== USER_NAV_PANEL) {
      return;
    }

    this.sidebarState.setPanel(MAIN_PANEL);
    this.sidebarState.isForcingSidebar = false;
    this.sidebarState.forcingSidebarPanel = null;
  }
}
