import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

const HIDE_SIDEBAR_KEY = "sidebar-hidden";

export default Controller.extend({
  queryParams: [{ sidebarQueryParamOverride: "enable_sidebar" }],

  showTop: true,
  showFooter: false,
  router: service(),
  showSidebar: false,
  sidebarQueryParamOverride: null,
  sidebarDisabledRouteOverride: false,
  showSiteHeader: true,

  init() {
    this._super(...arguments);
    this.showSidebar = this.calculateShowSidebar();
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

  @discourseComputed(
    "siteSettings.bootstrap_mode_enabled",
    "router.currentRouteName"
  )
  showBootstrapModeNotice(bootstrapModeEnabled, currentRouteName) {
    return (
      this.currentUser?.get("staff") &&
      bootstrapModeEnabled &&
      !currentRouteName.startsWith("wizard")
    );
  },

  @discourseComputed
  showFooterNav() {
    return this.capabilities.isAppWebview || this.capabilities.isiOSPWA;
  },

  _mainOutletAnimate() {
    document.querySelector("body").classList.remove("sidebar-animate");
  },

  @discourseComputed(
    "sidebarQueryParamOverride",
    "siteSettings.enable_sidebar",
    "canDisplaySidebar",
    "sidebarDisabledRouteOverride"
  )
  sidebarEnabled(
    sidebarQueryParamOverride,
    enableSidebar,
    canDisplaySidebar,
    sidebarDisabledRouteOverride
  ) {
    if (!canDisplaySidebar) {
      return false;
    }

    if (sidebarDisabledRouteOverride) {
      return false;
    }

    if (sidebarQueryParamOverride === "1") {
      return true;
    }

    if (sidebarQueryParamOverride === "0") {
      return false;
    }

    // Always return dropdown on mobile
    if (this.site.mobileView) {
      return false;
    }

    return enableSidebar;
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
