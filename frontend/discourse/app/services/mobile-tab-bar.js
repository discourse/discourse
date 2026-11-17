import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import scrollLock from "discourse/lib/scroll-lock";
import { scrollTop } from "discourse/lib/scroll-top";
import { ADMIN_PANEL, MAIN_PANEL } from "discourse/lib/sidebar/panels";
import DiscourseURL from "discourse/lib/url";
import { postRNWebviewMessage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const LOADING_ROUTE = /(^|[._-])loading$/;

const MAX_TABS = 4;
const HUB_TAB = "hub";
const USER_DRAFTS_CHANGED_EVENT = "user-drafts:changed";

/** Remembers navigation within sidebar panels that provide a `mobileTab`. */
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

  /** The section the current page belongs to, if any. */
  @tracked sectionTabKey = MAIN_PANEL;

  /** Whether the current page sits below its section's top level. */
  @tracked isNestedPage = false;

  /** Whether the current page puts its own title in the header. */
  @tracked isTitledPage = false;

  @tracked draftCount = this.currentUser?.draft_count ?? 0;

  /**
   * Where the current section renders its list views, above the tabs, with
   * `in-element`. Null while the bar is hidden.
   *
   * @type {HTMLElement|null}
   */
  @tracked viewsSlot = null;

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

  /** Whether the tab bar stands in for the header's menu on this page view. */
  get enabled() {
    return (
      this.siteSettings.mobile_footer_navigation &&
      this.site.mobileView &&
      // Visitors to a private site have only the login page to see
      (!!this.currentUser || !this.siteSettings.login_required)
    );
  }

  /** @returns {Array<Object>} The tabs, in the order the bar shows them. */
  get tabs() {
    return this.#allTabs;
  }

  /** @returns {Array<Object>} The tabs shown on the bar itself. */
  get barTabs() {
    const tabs = this.#allTabs;
    return tabs.length > MAX_TABS ? tabs.slice(0, MAX_TABS - 1) : tabs;
  }

  /** @returns {Array<Object>} The tabs gathered under the bar's More tab. */
  get moreTabs() {
    const tabs = this.#allTabs;
    return tabs.length > MAX_TABS ? tabs.slice(MAX_TABS - 1) : [];
  }

  /** Whether the current section is one gathered under More. */
  get isMoreActive() {
    return this.moreTabs.some((tab) => this.isActive(tab));
  }

  /**
   * @returns {Array<{label: string, icon: string, action: Function}>} Every
   * way to start something new, the current section's first, then drafts.
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

  // Forum, then primary sections so they stay on the bar rather than under
  // More, then the rest and admin. Inside the app, a tab back to its list of
  // sites leads.
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

    if (!routeInfo) {
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

    const owner = this.#ownerOf(route);

    // Pages of their own, like search or profiles, sit outside every section,
    // so each tab still returns to where its section was left
    if (!owner) {
      this.sectionTabKey = null;
      this.isNestedPage = false;
      this.isTitledPage = false;
      return;
    }

    this.sectionTabKey = owner.key;

    const url = this.router.currentURL;
    const tab = this.#tab(this.sectionTabKey);
    this.isNestedPage = !!tab?.isNestedRoute?.(route);
    this.isTitledPage =
      this.isNestedPage && (tab?.showsTitleInHeader?.(route) ?? true);
    this.#lastURLs.set(this.sectionTabKey, url);

    if (!this.isNestedPage) {
      this.#parentURLs.set(this.sectionTabKey, url);
    }
  }

  /**
   * Goes to where the user last was in the tab's section. On the current
   * section, climbs a level instead: back to the list, then the section's
   * top level, then the top of the page.
   *
   * @param {string} key
   */
  @bind
  selectTab(key) {
    const tab = this.#tab(key);
    this.closeMenu();

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

  // Other sections claim pages within the forum's, like topics that are
  // their own conversations, so they're asked before the forum
  #ownerOf(route) {
    const owns = (tab) => tab.ownsRoute?.(route);
    const tabs = this.#allTabs;

    return (
      tabs.find((tab) => tab.key !== MAIN_PANEL && owns(tab)) ??
      tabs.find((tab) => tab.key === MAIN_PANEL && owns(tab))
    );
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
