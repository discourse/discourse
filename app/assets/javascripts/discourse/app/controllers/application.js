import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default Controller.extend({
  queryParams: ["enable_sidebar"],

  showTop: true,
  showFooter: false,
  router: service(),
  showSidebar: null,
  hideSidebarKey: "sidebar-hidden",
  enable_sidebar: null,

  init() {
    this._super(...arguments);

    this.showSidebar = this.site.mobileView
      ? false
      : this.currentUser && !this.keyValueStore.getItem(this.hideSidebarKey);
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
  loginRequired() {
    return this.siteSettings.login_required && !this.currentUser;
  },

  @discourseComputed
  showBootstrapModeNotice() {
    return (
      this.currentUser?.get("staff") &&
      this.siteSettings.bootstrap_mode_enabled &&
      !this.router.currentRouteName.startsWith("wizard")
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
    "enable_sidebar",
    "siteSettings.enable_sidebar",
    "router.currentRouteName"
  )
  sidebarEnabled(sidebarQueryParamOverride, enableSidebar, currentRouteName) {
    if (sidebarQueryParamOverride === "1") {
      return true;
    }

    if (sidebarQueryParamOverride === "0") {
      return false;
    }

    if (currentRouteName.startsWith("wizard")) {
      return false;
    }

    return enableSidebar;
  },

  @action
  toggleSidebar() {
    // enables CSS transitions, but not on did-insert
    document.querySelector("body").classList.add("sidebar-animate");

    discourseDebounce(this, this._mainOutletAnimate, 250);

    this.toggleProperty("showSidebar");

    if (this.site.desktopView) {
      if (this.showSidebar) {
        this.keyValueStore.removeItem(this.hideSidebarKey);
      } else {
        this.keyValueStore.setItem(this.hideSidebarKey);
      }
    }
  },
});
