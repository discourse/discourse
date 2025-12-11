import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import runAfterFramePaint from "discourse/lib/after-frame-paint";
import discourseDebounce from "discourse/lib/debounce";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import EmbedMode from "discourse/lib/embed-mode";
import { isTesting } from "discourse/lib/environment";

const HIDE_SIDEBAR_KEY = "sidebar-hidden";

export default class ApplicationController extends Controller {
  @service footer;
  // eslint-disable-next-line discourse/no-unused-services
  @service router; // used in the route template
  @service sidebarState;
  @service siteSettings;

  queryParams = [{ navigationMenuQueryParamOverride: "navigation_menu" }];
  showTop = true;

  sidebarDisabledRouteOverride = false;
  navigationMenuQueryParamOverride = null;
  _showSiteHeader = true;
  @tracked _showSidebar;

  get upcomingChangeBodyClasses() {
    if (!this.siteSettings.currentUserUpcomingChanges) {
      return "";
    }

    const classes = [];

    Object.keys(this.siteSettings.currentUserUpcomingChanges).forEach((key) => {
      if (this.siteSettings[key]) {
        classes.push(`uc-${dasherize(key)}`);
      }
    });

    return classes.join(" ");
  }

  get showSiteHeader() {
    if (EmbedMode.enabled) {
      return false;
    }
    return this._showSiteHeader;
  }

  set showSiteHeader(value) {
    this._showSiteHeader = value;
  }

  // Some themes may need to override the default value provided by `calculateShowSidebar` using viewport properties.
  // Accessing the value in a getter prevents static viewport initialization warnings.
  get showSidebar() {
    return this._showSidebar ?? this.calculateShowSidebar();
  }

  set showSidebar(value) {
    this._showSidebar = value;
  }

  get showFooter() {
    return this.footer.showFooter;
  }

  set showFooter(value) {
    deprecated(
      "showFooter state is now stored in the `footer` service, and should be controlled by adding the {{hideApplicationFooter}} helper to an Ember template.",
      { id: "discourse.application-show-footer" }
    );
    this.footer.showFooter = value;
  }

  get showPoweredBy() {
    return this.showFooter && this.siteSettings.enable_powered_by_discourse;
  }

  @discourseComputed
  canSignUp() {
    return (
      !this.siteSettings.invite_only &&
      this.siteSettings.allow_new_registrations &&
      !this.siteSettings.enable_discourse_connect
    );
  }

  @discourseComputed
  canDisplaySidebar() {
    return this.currentUser || !this.siteSettings.login_required;
  }

  @discourseComputed
  loginRequired() {
    return this.siteSettings.login_required && !this.currentUser;
  }

  @discourseComputed
  showFooterNav() {
    return this.capabilities.isAppWebview || this.capabilities.isiOSPWA;
  }

  _mainOutletAnimate() {
    document.body.classList.remove("sidebar-animate");
  }

  get sidebarEnabled() {
    if (EmbedMode.enabled) {
      return false;
    }

    if (!this.canDisplaySidebar) {
      return false;
    }

    if (this.sidebarState.sidebarHidden) {
      return false;
    }

    if (this.sidebarDisabledRouteOverride) {
      return false;
    }

    if (this.navigationMenuQueryParamOverride === "sidebar") {
      return true;
    }

    if (this.navigationMenuQueryParamOverride === "header_dropdown") {
      return false;
    }

    // Always return dropdown on mobile
    if (this.site.mobileView) {
      return false;
    }

    // Always show sidebar for admin if user can see the admin sidebar
    if (this.sidebarState.isForcingSidebar) {
      return true;
    }

    return this.siteSettings.navigation_menu === "sidebar";
  }

  calculateShowSidebar() {
    return (
      this.canDisplaySidebar &&
      !this.keyValueStore.getItem(HIDE_SIDEBAR_KEY) &&
      !this.site.narrowDesktopView
    );
  }

  @action
  toggleSidebar() {
    // enables CSS transitions, but not on did-insert
    document.body.classList.add("sidebar-animate");

    discourseDebounce(this, this._mainOutletAnimate, 250);

    this.toggleProperty("showSidebar");

    if (this.site.desktopView) {
      if (this.showSidebar) {
        this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);
      } else {
        this.keyValueStore.setItem(HIDE_SIDEBAR_KEY, "true");
      }
    }
  }

  @action
  trackDiscoursePainted() {
    if (isTesting()) {
      return;
    }
    runAfterFramePaint(() => {
      performance.mark("discourse-paint");
      try {
        performance.measure(
          "discourse-init-to-paint",
          "discourse-init",
          "discourse-paint"
        );
      } catch (e) {
        // eslint-disable-next-line no-console
        console.warn("Failed to measure init-to-paint", e);
      }
    });
  }
}
