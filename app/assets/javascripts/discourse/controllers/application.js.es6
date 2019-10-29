import { inject as service } from '@ember/service';
import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import { isAppWebview, isiOSPWA } from "discourse/lib/utilities";

export default Controller.extend({
  showTop: true,
  showFooter: false,
  router: service(),

  @computed
  canSignUp() {
    return (
      !Discourse.SiteSettings.invite_only &&
      Discourse.SiteSettings.allow_new_registrations &&
      !Discourse.SiteSettings.enable_sso
    );
  },

  @computed
  loginRequired() {
    return Discourse.SiteSettings.login_required && !this.currentUser;
  },

  @computed
  showFooterNav() {
    return isAppWebview() || isiOSPWA();
  }
});
