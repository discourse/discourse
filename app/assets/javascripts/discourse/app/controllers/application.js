import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";

export default Controller.extend({
  showTop: true,
  showFooter: false,
  router: service(),

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
