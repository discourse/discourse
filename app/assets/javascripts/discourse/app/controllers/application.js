import discourseComputed from "discourse-common/utils/decorators";
import { inject as service } from "@ember/service";
import Controller from "@ember/controller";
import { isAppWebview, isiOSPWA } from "discourse/lib/utilities";

export default Controller.extend({
  showTop: true,
  showFooter: false,
  router: service(),

  @discourseComputed
  canSignUp() {
    return (
      !Discourse.SiteSettings.invite_only &&
      Discourse.SiteSettings.allow_new_registrations &&
      !Discourse.SiteSettings.enable_sso
    );
  },

  @discourseComputed
  loginRequired() {
    return Discourse.SiteSettings.login_required && !this.currentUser;
  },

  @discourseComputed
  showFooterNav() {
    return isAppWebview() || isiOSPWA();
  }
});
