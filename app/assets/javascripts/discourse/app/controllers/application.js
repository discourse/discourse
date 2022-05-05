import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Controller.extend({
  showTop: true,
  showFooter: false,
  router: service(),
  showSidebar: true,

  @discourseComputed("showSidebar", "currentUser.experimental_sidebar_enabled")
  mainOutletWrapperClasses(showSidebar, experimentalSidebarEnabled) {
    return showSidebar && experimentalSidebarEnabled ? "has-sidebar" : "";
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
});
