import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import scrollLock from "discourse/lib/scroll-lock";
import { MAIN_PANEL, USER_NAV_PANEL } from "discourse/lib/sidebar/panels";
import User from "discourse/models/user";

/**
 * Hands the sidebar over to the user nav panel while the user routes are
 * active, and gives it back on the way out — the same trade
 * `AdminSidebarStateManager` makes for the admin area.
 */
export default class UserNavSidebarStateManager extends Service {
  @service currentUser;
  @service header;
  @service mobileTabBar;
  @service routeHistory;
  @service sidebarState;
  @service siteSettings;

  /**
   * Where the viewer was before they opened a user's admin page. Captured on
   * arrival rather than read from history as they go, so that moving between
   * that page's own tabs doesn't rewrite where they came from.
   */
  @tracked entryURL = null;

  /**
   * A `user` controller of its own for the current user's profile, so the
   * panel can show your profile from anywhere without touching the page's
   * controller.
   */
  @tracked ownProfileController = null;

  #ownProfileLoading = null;

  get enteredFromAdmin() {
    return !!this.entryURL?.startsWith("/admin");
  }

  get enabled() {
    return this.siteSettings.sidebar_user_navigation;
  }

  /**
   * @returns {Object|undefined} The controller holding the user the panel
   * shows and its visibility rules. Routes that force the panel put their user
   * on the `user` controller; otherwise the panel shows your own profile.
   */
  get navController() {
    if (this.sidebarState.forcingSidebarPanel === USER_NAV_PANEL) {
      return getOwner(this).lookup("controller:user");
    }

    return this.ownProfileController;
  }

  /**
   * With the mobile tab bar, someone else's profile keeps its navigation on
   * the page, so the menu can stay with the active tab.
   *
   * @param {Object} user The user whose profile is shown.
   * @returns {boolean} Whether the panel serves that profile.
   */
  servesProfileOf(user) {
    return (
      this.enabled &&
      (!this.mobileTabBar.splitsProfileMenu ||
        user?.id === this.currentUser?.id)
    );
  }

  /**
   * Loads the current user's full profile, which the panel needs to show it
   * outside a profile page.
   */
  loadOwnProfile() {
    if (!this.currentUser) {
      return;
    }

    this.#ownProfileLoading ??= User.findByUsername(
      this.currentUser.username
    ).then((user) => {
      this.ownProfileController = getOwner(this)
        .factoryFor("controller:user")
        .create({ model: user });
    });

    return this.#ownProfileLoading;
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
