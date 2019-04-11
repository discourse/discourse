import computed from "ember-addons/ember-computed-decorators";
import { isAppWebview, isiOSPWA, isChromePWA } from "discourse/lib/utilities";

export default Ember.Controller.extend({
  showTop: true,
  showFooter: false,

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
    return Discourse.SiteSettings.login_required && !Discourse.User.current();
  },

  @computed
  showFooterNav() {
    return (
      isAppWebview() ||
      isiOSPWA() ||
      (!this.site.isMobileDevice && isChromePWA())
    );
  }
});
