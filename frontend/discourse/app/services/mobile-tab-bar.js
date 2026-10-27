import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { arrangeTabs, MORE_TAB } from "discourse/lib/mobile-tab-bar";
import scrollLock from "discourse/lib/scroll-lock";
import { scrollTop } from "discourse/lib/scroll-top";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
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
 * `mobileTab`, plus search. Tabs go to their section and remember where the
 * user was; the current section's tab opens its panel as a menu, in place of
 * the header's hamburger menu.
 */
@disableImplicitInjections
export default class MobileTabBar extends Service {
  @service capabilities;
  @service currentUser;
  @service header;
  @service router;
  @service search;
  @service sidebarState;
  @service site;
  @service siteSettings;

  /** The section the current page belongs to. */
  @tracked sectionTabKey = MAIN_PANEL;

  /** Whether the current page sits below its section's top level. */
  @tracked isNestedPage = false;

  /** The panel the menu shows while it is open. */
  @tracked menuPanelKey = null;

  #lastURLs = new Map();

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

  /** The tabs to show, with any that don't fit held by a "More" tab. */
  get tabs() {
    return arrangeTabs(this.#allTabs, {
      foldOrder: [ADMIN_PANEL],
      keep: [
        MAIN_PANEL,
        SEARCH_TAB,
        HUB_TAB,
        ...this.#allTabs.filter((tab) => tab.primary).map((tab) => tab.key),
      ],
      moreTab: {
        key: MORE_TAB,
        label: i18n("mobile_tab_bar.more"),
        icon: "ellipsis",
      },
    });
  }

  /** The action at the top of the open menu, such as starting a new topic. */
  get menuAction() {
    return this.#tab(this.menuPanelKey)?.menuAction;
  }

  // Forum leads, then primary sections and search, which hold their slots.
  // Other sections follow, then admin, the first to fold into "More". Inside
  // the app, a tab back to its list of sites leads the bar.
  get #allTabs() {
    const panelTabs = this.sidebarState.panels
      .map((panel) => panel.mobileTab && { key: panel.key, ...panel.mobileTab })
      .filter(Boolean);
    const byKey = (key) => panelTabs.find((tab) => tab.key === key);
    const fixed = [MAIN_PANEL, ADMIN_PANEL];
    const sections = panelTabs.filter((tab) => !fixed.includes(tab.key));

    return [
      this.capabilities.isAppWebview && {
        key: HUB_TAB,
        label: i18n("mobile_tab_bar.hub"),
        icon: "fab-discourse",
      },
      byKey(MAIN_PANEL),
      ...sections.filter((tab) => tab.primary),
      this.site.can_search && {
        key: SEARCH_TAB,
        label: i18n("search.title"),
        icon: "magnifying-glass",
        url: this.search.fullPageSearchURL,
        ownsRoute: (routeInfo) => routeInfo.name === SEARCH_ROUTE,
      },
      ...sections.filter((tab) => !tab.primary),
      byKey(ADMIN_PANEL),
    ].filter(Boolean);
  }

  get #isSearchPage() {
    return this.router.currentRouteName === SEARCH_ROUTE;
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

  @bind
  routeDidChange() {
    const route = this.router.currentRoute;

    if (!this.enabled || !route || LOADING_ROUTE.test(route.name)) {
      return;
    }

    const owner = this.#allTabs.find((tab) => tab.ownsRoute?.(route));
    const isProfile = !owner && !!profileUsernameForRoute(route);

    // A profile stays in the section that led there
    if (owner) {
      this.sectionTabKey = owner.key;
    } else if (!isProfile) {
      this.sectionTabKey = MAIN_PANEL;
    }

    this.isNestedPage = !!this.#tab(this.sectionTabKey)?.isNestedRoute?.(route);

    // A profile only borrows its section, so returning to the section from
    // elsewhere would land on the profile under a different tab
    if (!isProfile) {
      this.#lastURLs.set(this.sectionTabKey, this.router.currentURL);
    }
  }

  /**
   * Goes to where the user last was in the tab's section. On the current
   * section, opens or closes its menu instead, or for search, focuses its
   * input.
   *
   * @param {string} key
   */
  @bind
  selectTab(key) {
    if (key === this.sectionTabKey && this.#hasPanel(key)) {
      this.#toggleMenu(key);
      return;
    }

    this.closeMenu();

    // The app's own list of sites is the only thing outside this one
    if (key === HUB_TAB) {
      postRNWebviewMessage("dismiss", true);
      return;
    }

    // Search starts fresh, so the page focuses its empty input
    if (key === SEARCH_TAB && this.#isSearchPage) {
      scrollTop();
      document.querySelector(".full-page-search")?.focus();
    } else {
      const lastURL = key !== SEARCH_TAB && this.#lastURLs.get(key);
      DiscourseURL.routeTo(lastURL || this.#tab(key).url);
    }
  }

  @bind
  closeMenu() {
    this.#setMenuVisible(false);
  }

  #tab(key) {
    return this.#allTabs.find((tab) => tab.key === key);
  }

  #hasPanel(key) {
    return this.sidebarState.panels.some((panel) => panel.key === key);
  }

  #isMenuOpen(key) {
    return this.header.hamburgerVisible && this.menuPanelKey === key;
  }

  #toggleMenu(key) {
    if (this.#isMenuOpen(key)) {
      this.closeMenu();
      return;
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
