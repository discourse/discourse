import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default Controller.extend({
  showTop: true,
  showFooter: false,
  router: service(),
  showSidebar: null,
  hideSidebarKey: "sidebar-hidden",

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
  showFooterNav() {
    return this.capabilities.isAppWebview || this.capabilities.isiOSPWA;
  },

  _mainOutletAnimate() {
    document
      .querySelector("#main-outlet")
      .classList.remove("main-outlet-animate");
  },

  @action
  toggleSidebar() {
    // enables CSS transitions, but not on did-insert
    document.querySelector("body").classList.add("sidebar-animate");

    // reduces CSS transition jank
    document.querySelector("#main-outlet").classList.add("main-outlet-animate");

    discourseDebounce(this, this._mainOutletAnimate, 250);

    this.toggleProperty("showSidebar");

    if (!this.site.mobileView) {
      if (this.showSidebar) {
        this.keyValueStore.removeItem(this.hideSidebarKey);
      } else {
        this.keyValueStore.setItem(this.hideSidebarKey);
      }
    }
  },
});
