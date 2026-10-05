import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { arrangeTabs, MORE_TAB } from "discourse/lib/mobile-tab-bar";
import scrollLock from "discourse/lib/scroll-lock";
import { scrollTop } from "discourse/lib/scroll-top";
import {
  ADMIN_PANEL,
  MAIN_PANEL,
  USER_NAV_PANEL,
} from "discourse/lib/sidebar/panels";
import { profileUsernameForRoute } from "discourse/lib/sidebar/user-nav-sidebar";
import DiscourseURL from "discourse/lib/url";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const LOADING_ROUTE = /(^|[._-])loading$/;
const SEARCH_ROUTE = "full-page-search";
const SEARCH_TAB = "search";
const HUB_TAB = "hub";

/**
 * Drives the mobile tab bar and the header controls that go with it. Each tab
 * is a section of the site: a sidebar panel that opted in through
 * `mobileTab`, plus search. Tabs navigate and remember where the user was;
 * the header's menu button opens the current section's panel.
 *
 * The sidebar can instead lead with the same tabs, which navigate the same
 * way and switch the sidebar to their section's panel.
 */
@disableImplicitInjections
export default class MobileTabBar extends Service {
  @service capabilities;
  @service currentUser;
  @service header;
  @service routeHistory;
  @service router;
  @service search;
  @service sidebarState;
  @service site;
  @service siteSettings;
  @service userNavSidebarStateManager;

  /** The section the current page belongs to. */
  @tracked sectionTabKey = MAIN_PANEL;

  /** Whether the current page sits below its section's top level. */
  @tracked isNestedPage = false;

  /** The panel the menu shows while it is open. */
  @tracked menuPanelKey = null;

  #lastURLs = new Map();
  #panelBeforeProfile = null;
  #parentURLs = new Map();

  init() {
    super.init(...arguments);
    this.router.on("routeDidChange", this.routeDidChange);

    if (this.router.currentRoute) {
      this.routeDidChange();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this.routeDidChange);
  }

  get enabled() {
    return (
      !!this.currentUser &&
      this.siteSettings.enable_mobile_tab_bar &&
      this.site.mobileView &&
      this.#allTabs.length > 1
    );
  }

  /**
   * Whether the sidebar would lead with tabs, before the footer bar has its
   * say. Safe to read while the app boots, as it doesn't touch the viewport.
   */
  get sidebarTabsConfigured() {
    return (
      !!this.currentUser &&
      this.siteSettings.enable_sidebar_tab_bar &&
      this.#panelTabs.length > 1
    );
  }

  // The footer bar takes over on mobile when both are on
  get sidebarTabsEnabled() {
    return this.sidebarTabsConfigured && !this.enabled;
  }

  /** The tabs to show, with any that don't fit held by a "More" tab. */
  get tabs() {
    return this.#arrange(this.#allTabs);
  }

  /** The sidebar's tabs, one per panel. */
  get sidebarTabs() {
    return this.#arrange(this.#panelTabs);
  }

  /**
   * Whether the header splits notifications from the profile menu: a bell for
   * notifications, and the avatar for your profile and account controls.
   */
  get splitsProfileMenu() {
    return this.enabled || this.sidebarTabsEnabled;
  }

  get isProfileMenuOpen() {
    if (this.#profileOpensInSidebar) {
      return (
        this.sidebarState.currentPanelKey === USER_NAV_PANEL &&
        this.userNavSidebarStateManager.navController?.model?.id ===
          this.currentUser?.id
      );
    }

    return this.#isMenuOpen(USER_NAV_PANEL);
  }

  get isSectionMenuOpen() {
    return this.#isMenuOpen(this.#sectionPanelKey);
  }

  /** The action at the top of the open menu, such as starting a new topic. */
  get menuAction() {
    return this.#tab(this.menuPanelKey)?.menuAction;
  }

  // Forum leads, then primary sections and search, which hold their slots.
  // Other sections follow, then admin, the first to fold into "More". Inside
  // the app, a tab back to its list of sites leads the bar.
  get #allTabs() {
    const panelTabs = this.#panelTabs;
    const primaryCount = panelTabs.filter(
      (tab) => tab.key === MAIN_PANEL || tab.primary
    ).length;

    return [
      this.capabilities.isAppWebview && {
        key: HUB_TAB,
        label: i18n("mobile_tab_bar.hub"),
        icon: "fab-discourse",
      },
      ...panelTabs.slice(0, primaryCount),
      this.site.can_search && {
        key: SEARCH_TAB,
        label: i18n("search.title"),
        icon: "magnifying-glass",
        url: this.search.fullPageSearchURL,
        ownsRoute: (routeInfo) => routeInfo.name === SEARCH_ROUTE,
      },
      ...panelTabs.slice(primaryCount),
    ].filter(Boolean);
  }

  // Forum, primary sections, other sections, then admin
  get #panelTabs() {
    const tabs = this.sidebarState.panels
      .map((panel) => panel.mobileTab && { key: panel.key, ...panel.mobileTab })
      .filter(Boolean);
    const byKey = (key) => tabs.find((tab) => tab.key === key);
    const fixed = [MAIN_PANEL, ADMIN_PANEL];
    const sections = tabs
      .filter((tab) => !fixed.includes(tab.key))
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0));

    return [
      byKey(MAIN_PANEL),
      ...sections.filter((tab) => tab.primary),
      ...sections.filter((tab) => !tab.primary),
      byKey(ADMIN_PANEL),
    ].filter(Boolean);
  }

  // Search has no panel of its own, so its menu is the forum's
  get #sectionPanelKey() {
    return this.sidebarState.panels.some(
      (panel) => panel.key === this.sectionTabKey
    )
      ? this.sectionTabKey
      : MAIN_PANEL;
  }

  get #isSearchPage() {
    return this.router.currentRouteName === SEARCH_ROUTE;
  }

  // On desktop the sidebar stays put, so the profile opens in it rather than
  // in a menu over the page
  get #profileOpensInSidebar() {
    return this.sidebarTabsEnabled && this.site.desktopView;
  }

  /**
   * @param {Object} tab A tab from `tabs`.
   * @returns {boolean} Whether the tab, or one it holds, is the current section.
   */
  @bind
  isActive(tab) {
    return (
      tab.key === this.sectionTabKey ||
      !!tab.overflow?.some((held) => held.key === this.sectionTabKey)
    );
  }

  /**
   * @param {Object} tab A tab from `sidebarTabs`.
   * @returns {boolean} Whether the sidebar shows the tab's panel, or the
   * panel of one it holds.
   */
  @bind
  isSidebarTabActive(tab) {
    const key = this.sidebarState.currentPanelKey;
    return tab.key === key || !!tab.overflow?.some((held) => held.key === key);
  }

  @bind
  routeDidChange() {
    const route = this.router.currentRoute;
    const tracking = this.enabled || this.sidebarTabsEnabled;

    if (!tracking || !route || LOADING_ROUTE.test(route.name)) {
      return;
    }

    const owner = this.#allTabs.find((tab) => tab.ownsRoute?.(route));
    const previousSectionKey = this.sectionTabKey;

    // A profile stays in the section that led there
    if (owner) {
      this.sectionTabKey = owner.key;
    } else if (!profileUsernameForRoute(route)) {
      this.sectionTabKey = MAIN_PANEL;
    }

    // Links between sections move the sidebar along, as the tabs do
    if (
      this.sidebarTabsEnabled &&
      this.sectionTabKey !== previousSectionKey &&
      !this.sidebarState.isForcingSidebar &&
      this.#panelTabs.some((tab) => tab.key === this.sectionTabKey)
    ) {
      this.sidebarState.setPanel(this.sectionTabKey);
    }

    const url = this.router.currentURL;
    this.isNestedPage = !!this.#tab(this.sectionTabKey)?.isNestedRoute?.(route);
    this.#lastURLs.set(this.sectionTabKey, url);

    if (!this.isNestedPage) {
      this.#parentURLs.set(this.sectionTabKey, url);
    }
  }

  /**
   * Goes to where the user last was in the tab's section. On the current
   * section, climbs one level at a time: from a nested page back to the list
   * it was opened from, then to the section's top level, then to the top of
   * the page.
   *
   * @param {string} key
   */
  @bind
  selectTab(key) {
    const tab = this.#tab(key);
    this.closeMenu();

    // The app's own list of sites is the only thing outside this one
    if (key === HUB_TAB) {
      postRNWebviewMessage("dismiss", true);
      return;
    }

    // Search starts fresh, so the page focuses its empty input
    if (key !== this.sectionTabKey) {
      const lastURL = key !== SEARCH_TAB && this.#lastURLs.get(key);
      tab.beforeNavigate?.();
      DiscourseURL.routeTo(lastURL || tab.url);
    } else if (this.isNestedPage) {
      this.#returnToList(tab);
    } else if (this.router.currentURL !== tab.url && !this.#isSearchPage) {
      DiscourseURL.routeTo(tab.url);
    } else {
      scrollTop();

      if (this.#isSearchPage) {
        document.querySelector(".full-page-search")?.focus();
      }
    }
  }

  /**
   * Goes to the tab's section as `selectTab` does, showing its panel.
   *
   * @param {string} key
   */
  @bind
  selectSidebarTab(key) {
    this.selectTab(key);

    // Set ahead of the transition, so routes leaving their section don't
    // reset the sidebar over it
    this.sidebarState.setPanel(key);
  }

  @bind
  toggleSectionMenu() {
    this.#toggleMenu(this.#sectionPanelKey);
  }

  @bind
  toggleProfileMenu() {
    if (!this.#profileOpensInSidebar) {
      this.#toggleMenu(USER_NAV_PANEL);
      return;
    }

    if (this.isProfileMenuOpen) {
      this.sidebarState.setPanel(
        this.#panelBeforeProfile ?? this.#sectionPanelKey
      );
      return;
    }

    this.userNavSidebarStateManager.loadOwnProfile();
    this.#panelBeforeProfile = this.sidebarState.currentPanelKey;
    this.sidebarState.setPanel(USER_NAV_PANEL);

    const application = getOwner(this).lookup("controller:application");
    if (!application.showSidebar) {
      application.toggleSidebar();
    }
  }

  @bind
  closeMenu() {
    this.#setMenuVisible(false);
  }

  #arrange(tabs) {
    return arrangeTabs(tabs, {
      foldOrder: [ADMIN_PANEL],
      keep: [
        MAIN_PANEL,
        SEARCH_TAB,
        HUB_TAB,
        ...tabs.filter((tab) => tab.primary).map((tab) => tab.key),
      ],
      moreTab: {
        key: MORE_TAB,
        label: i18n("mobile_tab_bar.more"),
        icon: "ellipsis",
      },
    });
  }

  #tab(key) {
    return this.#allTabs.find((tab) => tab.key === key);
  }

  // Stepping back through history keeps the list's scroll position
  #returnToList(tab) {
    const parent = this.#parentURLs.get(tab.key) || tab.url;

    if (this.routeHistory.lastURL === parent) {
      window.history.back();
    } else {
      DiscourseURL.routeTo(parent);
    }
  }

  #isMenuOpen(key) {
    return this.header.hamburgerVisible && this.menuPanelKey === key;
  }

  #toggleMenu(key) {
    if (this.#isMenuOpen(key)) {
      this.closeMenu();
      return;
    }

    if (key === USER_NAV_PANEL) {
      this.userNavSidebarStateManager.loadOwnProfile();
    }

    this.menuPanelKey = key;
    this.sidebarState.setPanel(key);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.header.userVisible = false;
    this.#setMenuVisible(true);
  }

  #setMenuVisible(visible) {
    this.header.hamburgerVisible = visible;
    scrollLock(visible);
  }
}
