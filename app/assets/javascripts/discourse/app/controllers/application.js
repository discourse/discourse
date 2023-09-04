import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import deprecated from "discourse-common/lib/deprecated";

const HIDE_SIDEBAR_KEY = "sidebar-hidden";

export default Controller.extend({
  queryParams: [{ navigationMenuQueryParamOverride: "navigation_menu" }],

  showTop: true,
  router: service(),
  footer: service(),
  showSidebar: false,
  navigationMenuQueryParamOverride: null,
  sidebarDisabledRouteOverride: false,
  showSiteHeader: true,

  init() {
    this._super(...arguments);
    this.showSidebar = this.calculateShowSidebar();
  },

  get showFooter() {
    return this.footer.showFooter;
  },

  set showFooter(value) {
    deprecated(
      "showFooter state is now stored in the `footer` service, and should be controlled by adding the {{hide-application-footer}} helper to an Ember template.",
      { id: "discourse.application-show-footer" }
    );
    this.footer.showFooter = value;
  },

  @discourseComputed
  canSignUp() {
    return (
      !this.siteSettings.invite_only &&
      this.siteSettings.allow_new_registrations &&
      !this.siteSettings.enable_discourse_connect
    );
  },

  @discourseComputed
  canDisplaySidebar() {
    return this.currentUser || !this.siteSettings.login_required;
  },

  @discourseComputed
  loginRequired() {
    return this.siteSettings.login_required && !this.currentUser;
  },

  @discourseComputed
  showFooterNav() {
    return this.capabilities.isAppWebview || this.capabilities.isiOSPWA;
  },

  _mainOutletAnimate() {
    document.querySelector("body").classList.remove("sidebar-animate");
  },

  @discourseComputed(
    "navigationMenuQueryParamOverride",
    "siteSettings.navigation_menu",
    "canDisplaySidebar",
    "sidebarDisabledRouteOverride"
  )
  sidebarEnabled(
    navigationMenuQueryParamOverride,
    navigationMenu,
    canDisplaySidebar,
    sidebarDisabledRouteOverride
  ) {
    if (!canDisplaySidebar) {
      return false;
    }

    if (sidebarDisabledRouteOverride) {
      return false;
    }

    if (navigationMenuQueryParamOverride === "sidebar") {
      return true;
    }

    if (
      navigationMenuQueryParamOverride === "legacy" ||
      navigationMenuQueryParamOverride === "header_dropdown"
    ) {
      return false;
    }

    // Always return dropdown on mobile
    if (this.site.mobileView) {
      return false;
    }

    return navigationMenu === "sidebar";
  },

  calculateShowSidebar() {
    return (
      this.canDisplaySidebar &&
      !this.keyValueStore.getItem(HIDE_SIDEBAR_KEY) &&
      !this.site.narrowDesktopView
    );
  },

  @action
  toggleSidebar() {
    // enables CSS transitions, but not on did-insert
    document.querySelector("body").classList.add("sidebar-animate");

    discourseDebounce(this, this._mainOutletAnimate, 250);

    this.toggleProperty("showSidebar");

    if (this.site.desktopView) {
      if (this.showSidebar) {
        this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);
      } else {
        this.keyValueStore.setItem(HIDE_SIDEBAR_KEY, "true");
      }
    }
  },
});
