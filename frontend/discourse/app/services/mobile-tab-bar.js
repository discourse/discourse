import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import scrollLock from "discourse/lib/scroll-lock";
import { scrollTop } from "discourse/lib/scroll-top";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import { profileUsernameForRoute } from "discourse/lib/sidebar/user-nav-sidebar";
import DiscourseURL from "discourse/lib/url";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const LOADING_ROUTE = /(^|[._-])loading$/;
const HUB_TAB = "hub";
const USER_DRAFTS_CHANGED_EVENT = "user-drafts:changed";

/**
 * Drives the mobile tab bar. Each tab is a section of the site: a sidebar
 * panel that opted in through `mobileTab`. Tabs navigate and remember where
 * the user was. The menu button, always first, opens the forum's menu
 * wherever the user is, since other sections keep their navigation on their
 * own pages, and the create button, always last, starts something new in any
 * section.
 */
@disableImplicitInjections
export default class MobileTabBar extends Service {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service header;
  @service routeHistory;
  @service router;
  @service sidebarState;
  @service site;
  @service siteSettings;

  /** The section the current page belongs to. */
  @tracked sectionTabKey = MAIN_PANEL;

  /** Whether the current page sits below its section's top level. */
  @tracked isNestedPage = false;

  /** Whether the current page puts its own title in the header. */
  @tracked isTitledPage = false;

  @tracked draftCount = this.currentUser?.draft_count ?? 0;

  #lastURLs = new Map();
  #parentURLs = new Map();

  init() {
    super.init(...arguments);
    this.router.on("routeDidChange", this.routeDidChange);
    this.appEvents.on(USER_DRAFTS_CHANGED_EVENT, this, this.#updateDraftCount);

    if (this.router.currentRoute) {
      this.routeDidChange();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this.routeDidChange);
    this.appEvents.off(USER_DRAFTS_CHANGED_EVENT, this, this.#updateDraftCount);
  }

  get enabled() {
    return (
      !!this.currentUser &&
      this.siteSettings.enable_mobile_tab_bar &&
      this.site.mobileView
    );
  }

  /**
   * The tabs to show between the menu and create buttons, which scroll when
   * they don't all fit.
   *
   * @returns {Array<Object>}
   */
  get tabs() {
    return this.#allTabs;
  }

  /**
   * Every way to start something new, the current section's first, then a way
   * back to unfinished drafts.
   *
   * @returns {Array<{label: string, icon: string, action: Function}>}
   */
  get createActions() {
    const tabs = this.#allTabs;
    const current = tabs.filter((tab) => tab.key === this.sectionTabKey);
    const others = tabs.filter((tab) => tab.key !== this.sectionTabKey);
    const actions = [...current, ...others].flatMap(
      (tab) => tab.createActions || []
    );

    if (this.draftCount > 0) {
      actions.push({
        label: i18n("mobile_tab_bar.drafts", { count: this.draftCount }),
        icon: "pencil",
        action: () =>
          this.router.transitionTo("userActivity.drafts", this.currentUser),
      });
    }

    return actions;
  }

  get isMenuOpen() {
    return this.header.hamburgerVisible;
  }

  // Forum leads, then primary sections, so they show without scrolling. Other
  // sections follow, then admin. Inside the app, a tab back to its list of
  // sites leads the bar.
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
      ...sections.filter((tab) => !tab.primary),
      byKey(ADMIN_PANEL),
    ].filter(Boolean);
  }

  /**
   * @param {Object} tab A tab from `tabs`.
   * @returns {boolean} Whether the tab is the current section.
   */
  @bind
  isActive(tab) {
    return tab.key === this.sectionTabKey;
  }

  /**
   * The forum's menu leaves out links to sections that have their own tab.
   *
   * @param {Object} link A sidebar section link.
   * @returns {boolean} Whether the link leads into a section other than the
   * forum that has a tab of its own.
   */
  @bind
  leadsToSectionTab(link) {
    let routeInfo;

    try {
      const models = link.models ?? (link.model ? [link.model] : []);
      // Links built from the admin-edited section keep their URL as `value`
      const url =
        link.href ??
        (link.route
          ? this.router.urlFor(link.route, ...models, {
              queryParams: link.query ?? {},
            })
          : link.value);
      routeInfo = this.router.recognize(url);
    } catch {
      return false;
    }

    return this.#allTabs.some(
      (tab) => tab.key !== MAIN_PANEL && tab.ownsRoute?.(routeInfo)
    );
  }

  @bind
  routeDidChange() {
    const route = this.router.currentRoute;

    if (!this.enabled || !route || LOADING_ROUTE.test(route.name)) {
      return;
    }

    const owner = this.#allTabs.find((tab) => tab.ownsRoute?.(route));

    // A profile stays in the section that led there
    if (owner) {
      this.sectionTabKey = owner.key;
    } else if (!profileUsernameForRoute(route)) {
      this.sectionTabKey = MAIN_PANEL;
    }

    const url = this.router.currentURL;
    const tab = this.#tab(this.sectionTabKey);
    this.isNestedPage = !!tab?.isNestedRoute?.(route);
    this.isTitledPage = this.isNestedPage && !!tab?.showsTitleInHeader?.(route);
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

    if (key !== this.sectionTabKey) {
      DiscourseURL.routeTo(this.#lastURLs.get(key) || tab.url);
    } else if (this.isNestedPage) {
      this.#returnToList(tab);
    } else if (this.router.currentURL !== tab.url) {
      DiscourseURL.routeTo(tab.url);
    } else {
      scrollTop();
    }
  }

  /** Returns from a nested page to the list it was opened from. */
  @bind
  goBack() {
    this.#returnToList(this.#tab(this.sectionTabKey));
  }

  @bind
  toggleMenu() {
    if (this.isMenuOpen) {
      this.closeMenu();
      return;
    }

    this.sidebarState.setPanel(MAIN_PANEL);
    this.sidebarState.setSeparatedMode();
    this.sidebarState.hideSwitchPanelButtons();
    this.header.userVisible = false;
    this.#setMenuVisible(true);
  }

  @bind
  closeMenu() {
    this.#setMenuVisible(false);
  }

  #updateDraftCount() {
    this.draftCount = this.currentUser?.draft_count ?? 0;
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

  #setMenuVisible(visible) {
    this.header.hamburgerVisible = visible;
    scrollLock(visible);
  }
}
